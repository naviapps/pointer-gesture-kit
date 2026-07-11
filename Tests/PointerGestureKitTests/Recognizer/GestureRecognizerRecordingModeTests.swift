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
    assertDisposition(result, .consume)
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
          case let .dragStart(_, points):
            XCTFail("Unexpected partial drag replay with \(points.count) points.")
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
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

  func testLastRecordedDirectionsRemainUntilNextGestureCompletes() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 0, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 0))
    )
    XCTAssertEqual(recognizer.snapshot.status.lastRecordedDirections, [.right])

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 0, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 0, y: 40))
    )

    XCTAssertEqual(recognizer.snapshot.status.lastRecordedDirections, [.right])

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 0, y: 40))
    )

    XCTAssertEqual(recognizer.snapshot.status.lastRecordedDirections, [.down])
  }

  func testRecordingModeRecordsAllCardinalDirections() {
    let cases: [(end: GesturePoint, direction: GestureDirection)] = [
      (.init(x: 30, y: 0), .right),
      (.init(x: -30, y: 0), .left),
      (.init(x: 0, y: 30), .down),
      (.init(x: 0, y: -30), .up),
    ]

    for testCase in cases {
      let eventSource = GestureEventSourceDouble(startResult: true)
      let recognizer = GestureRecognizer<UUID>(
        eventSource: eventSource,
        configuration: makeGestureRecognizerTestConfiguration(
          tuning: .testing(
            minimumGestureStartAxisDistance: 0,
            minimumDirectionChangeAxisDistance: 0
          )
        )
      )
      recognizer.isRecordingModeEnabled = true
      recognizer.start()

      _ = eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
      )
      _ = eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: testCase.end)
      )
      _ = eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: testCase.end)
      )

      XCTAssertEqual(recognizer.snapshot.status.lastRecordedDirections, [testCase.direction])
    }
  }

  func testRecordingModeRecordsDirectionsWithoutRequestingMatcher() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var makeMatcherCallCount = 0

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          makeMatcherCallCount += 1
          return GesturePatternMatcher<UUID>()
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 0))
    )

    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])
    XCTAssertEqual(recognizer.snapshot.trace.directionEndpoints, [.zero, .init(x: 30, y: 0)])
    XCTAssertEqual(makeMatcherCallCount, 0)
  }

  func testRecordingModeSessionContinuesRecordingWhenModeIsDisabledMidGesture() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var makeMatcherCallCount = 0
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          makeMatcherCallCount += 1
          return GesturePatternMatcher<UUID>()
        },
        onReplayRequested: { replayRequests.append($0) },
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )

    recognizer.isRecordingModeEnabled = false

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertEqual(makeMatcherCallCount, 0)
    XCTAssertEqual(recognizer.snapshot.status.lastRecordedDirections, [.right])
    assertReplayRequests(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [.zero, .init(x: 20, y: 0), .init(x: 40, y: 0)]
        )
      ]
    )
  }
}
