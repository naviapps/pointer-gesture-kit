import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerCancelEventTests: XCTestCase {
  func testCancelEventReplaysPendingButtonInput() {
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

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    assertDisposition(eventSource.send(makeCancelGestureInputEvent()), .consume)
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 10))
      ),
      .passThrough
    )

    assertReplayRequests(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testCancelEventCancelsActiveSessionAndRequestsReleaseReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { modifiers, _ in
          modifiers.contains(.command)
        },
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
      makeGestureInputEvent(
        kind: .buttonDown(.secondary),
        location: .init(x: 10, y: 10),
        modifiers: [.command]
      ))
    _ = eventSource.send(
      makeGestureInputEvent(
        kind: .buttonMoved(.secondary),
        location: .init(x: 40, y: 10),
        modifiers: [.command]
      ))
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)

    let result = eventSource.send(makeCancelGestureInputEvent())
    assertDisposition(result, .consume)
    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testCancelEventReplaysUnmatchedActiveSessionAsConsumedDrag() {
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10)))
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 60))
      ),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.directions.isEmpty)

    assertDisposition(eventSource.send(makeCancelGestureInputEvent()), .passThrough)
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 60))
      ),
      .passThrough
    )

    assertReplayRequests(
      replayRequests,
      [.dragStart(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 10, y: 60)])]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testCancelEventPassesThroughWhenNoButtonInputExists() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration()

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let result = eventSource.send(makeCancelGestureInputEvent())
    assertDisposition(result, .passThrough)
  }
}
