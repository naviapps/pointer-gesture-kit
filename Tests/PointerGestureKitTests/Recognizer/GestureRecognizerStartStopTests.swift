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
    XCTAssertEqual(
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 40, y: 10))
    )

    recognizer.stop()

    XCTAssertEqual(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 10))])
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

    XCTAssertEqual(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopReplaysMovedPendingButtonInput() {
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 20, y: 10))
    )

    recognizer.stop()

    XCTAssertEqual(
      replayRequests,
      [.drag(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 20, y: 10)])]
    )
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testStopReplaysStoppedConsumedButtonDrag() {
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
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 10, y: 60))
      ),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    recognizer.stop()

    XCTAssertEqual(
      replayRequests,
      [.drag(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 10, y: 60)])]
    )
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(eventSource.stopCount, 1)
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
