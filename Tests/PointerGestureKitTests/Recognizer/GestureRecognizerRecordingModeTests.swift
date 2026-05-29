import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerRecordingModeTests: XCTestCase {
  func testRecordingModeIgnoresModifierPolicy() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        areModifiersSatisfied: { modifiers, _ in
          modifiers.contains(.command)
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )
    recognizer.isRecordingModeEnabled = true

    recognizer.start()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)

    let down = makeGestureInputEvent(
      kind: .buttonDown(.secondary), location: .init(x: 10, y: 10), modifiers: [])
    let result = eventSource.send(down)
    XCTAssertEqual(result, .consume)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  func testRecordingModeRequestsButtonDragAfterRecordedGesture() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var sequencePoints: [GesturePoint] = []
    var releaseRequestCount = 0
    var clickRequestCount = 0

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { request in
          switch request {
          case .click:
            clickRequestCount += 1
          case let .drag(_, points):
            sequencePoints = points
          case let .release(_, point):
            releaseRequestCount += 1
            XCTFail("Unexpected release-only replay at \(point).")
          }
        },
        areModifiersSatisfied: { _, _ in false },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
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
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 60, y: 10))
    )

    XCTAssertEqual(
      sequencePoints,
      [.init(x: 10, y: 10), .init(x: 40, y: 10), .init(x: 60, y: 10)]
    )
    XCTAssertEqual(clickRequestCount, 0)
    XCTAssertEqual(releaseRequestCount, 0)
    XCTAssertEqual(recognizer.snapshot.status.lastRecordedDirections, [.right])
  }

  func testRecordingModeRecordsDirectionsWithoutRegisteredMatcher() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 20, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 0))
    )

    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])
    XCTAssertEqual(recognizer.snapshot.trace.directionEndpoints.last, .init(x: 30, y: 0))
  }
}
