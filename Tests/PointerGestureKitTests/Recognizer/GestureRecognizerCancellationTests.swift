import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerCancellationTests: XCTestCase {
  func testCancelActiveGestureDoesNothingBeforeStart() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.cancelActiveGesture()

    XCTAssertTrue(replayRequests.isEmpty)
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.startCount, 0)
    XCTAssertEqual(eventSource.stopCount, 0)
  }

  func testCancelActiveGestureRequestsButtonReleaseForActiveSession() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
    )
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)

    recognizer.cancelActiveGesture()

    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  func testCancelActiveGestureReplaysPendingButtonInput() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )

    recognizer.cancelActiveGesture()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 10))
      ),
      .passThrough
    )
    assertReplayRequests(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  func testCancelActiveGestureReplaysMovedPendingButtonInputBelowStartDistanceAsClick() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 25
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 19, y: 10))
    )

    recognizer.cancelActiveGesture()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 10))
      ),
      .passThrough
    )
    assertReplayRequests(
      replayRequests,
      [.click(button: .secondary, at: .init(x: 10, y: 10))]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  func testCancelActiveGestureClearsActiveSessionState() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let down = makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    _ = eventSource.send(down)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
    )
    XCTAssertTrue(recognizer.snapshot.trace.isVisible)

    recognizer.cancelActiveGesture()

    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testCancelActiveGestureHidesImmediatelyAfterVisibleExactMatchTrace() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var traceVisibility: [Bool] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )
    let observation = recognizer.observeTrace { trace in
      traceVisibility.append(trace.isVisible)
    }
    defer { observation.cancel() }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
    )

    recognizer.cancelActiveGesture()
    try? await Task.sleep(nanoseconds: 30_000_000)

    XCTAssertEqual(traceVisibility, [false, true, false])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testCancelActiveGesturePreservesLastFailureWhenNoGestureIsActive() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        areModifiersSatisfied: { _, _ in false }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .modifiersNotSatisfied)

    recognizer.cancelActiveGesture()

    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .modifiersNotSatisfied)
  }

  func testCancelActiveGesturePreservesStartFailureWhenNoGestureIsActive() {
    let eventSource = GestureEventSourceDouble(startResult: false)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .failed)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .eventSourceStartFailed)

    recognizer.cancelActiveGesture()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .failed)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .eventSourceStartFailed)
  }
}
