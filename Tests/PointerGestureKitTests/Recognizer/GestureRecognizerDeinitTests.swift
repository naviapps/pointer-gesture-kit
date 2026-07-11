import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerDeinitTests: XCTestCase {
  func testDeinitReleasesActiveButtonDrag() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    var stopCountWhenReplayWasRequested: Int?

    do {
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

      XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
    }

    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 10))])
    XCTAssertEqual(stopCountWhenReplayWasRequested, 0)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testDeinitReplaysMovedPendingButtonInputBelowStartDistanceAsClick() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    var stopCountWhenReplayWasRequested: Int?

    do {
      let configuration: GestureRecognizerConfiguration<UUID> =
        makeGestureRecognizerTestConfiguration(
          onReplayRequested: {
            stopCountWhenReplayWasRequested = eventSource.stopCount
            replayRequests.append($0)
          },
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

      XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    }

    assertReplayRequests(
      replayRequests,
      [.click(button: .secondary, at: .init(x: 10, y: 10))]
    )
    XCTAssertEqual(stopCountWhenReplayWasRequested, 0)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testDeinitFromAnotherActorReleasesActiveButtonDrag() async {
    let probe = GestureRecognizerDeinitProbe()

    await Task.detached { @Sendable [probe] in
      let recognizer = await probe.makeActiveRecognizer()
      _ = recognizer
    }.value

    await XCTAssertEventually {
      probe.replayRequests == [.release(button: .secondary, at: .init(x: 40, y: 10))]
    }
    XCTAssertEqual(probe.stopCountWhenReplayWasRequested, 0)
    XCTAssertEqual(probe.eventSource.stopCount, 1)
  }

}

@MainActor
private final class GestureRecognizerDeinitProbe {
  let eventSource = GestureEventSourceDouble(startResult: true)
  private(set) var replayRequests: [GestureReplayRequest] = []
  private(set) var stopCountWhenReplayWasRequested: Int?

  func makeActiveRecognizer() -> GestureRecognizer<UUID> {
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { [self] in
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

    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
    return recognizer
  }
}
