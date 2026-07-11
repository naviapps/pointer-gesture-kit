import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerStartStopTests: XCTestCase {
  func testStopDoesNothingBeforeStart() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration()
    )

    recognizer.stop()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.startCount, 0)
    XCTAssertEqual(eventSource.stopCount, 0)
  }

  func testStopTransitionsReadyRecognizerToIdleAndStopsEventSource() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration()

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertEqual(eventSource.startCount, 1)

    recognizer.stop()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertEqual(eventSource.stopCount, 1)
    assertDisposition(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .passThrough
    )
  }

  func testStopDoesNothingWhenRecognizerIsAlreadyIdle() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration()
    )

    recognizer.start()
    recognizer.stop()
    recognizer.stop()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertEqual(eventSource.startCount, 1)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopReleasesActiveButtonDrag() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    var stopCountWhenReplayWasRequested: Int?

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: {
          stopCountWhenReplayWasRequested = eventSource.stopCount
          replayRequests.append($0)
        },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 100
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )
    recognizer.isRecordingModeEnabled = true

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
    )

    recognizer.stop()

    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 10))])
    XCTAssertEqual(stopCountWhenReplayWasRequested, 0)
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopReplaysPendingButtonClick() {
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

    recognizer.stop()

    assertReplayRequests(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopReplaysMovedPendingButtonInputBelowStartDistanceAsClick() {
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

    recognizer.stop()

    assertReplayRequests(
      replayRequests,
      [.click(button: .secondary, at: .init(x: 10, y: 10))]
    )
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopReplaysUnmatchedActiveSessionAsConsumedButtonDrag() {
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 60))
      ),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.directions.isEmpty)

    recognizer.stop()

    assertReplayRequests(
      replayRequests,
      [.dragStart(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 10, y: 60)])]
    )
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopHidesImmediatelyAfterVisibleExactMatchTrace() async {
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

    recognizer.stop()
    try? await Task.sleep(nanoseconds: 30_000_000)

    XCTAssertEqual(traceVisibility, [false, true, false])
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testStopClearsLastFailure() {
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

    recognizer.stop()

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
  }

  func testStartCanRestartRecognizerAfterStop() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration()
    )

    recognizer.start()
    recognizer.stop()
    recognizer.start()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertEqual(eventSource.startCount, 2)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStartDoesNothingWhenRecognizerIsAlreadyReady() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration()
    )

    recognizer.start()
    recognizer.start()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertEqual(eventSource.startCount, 1)
  }
}
