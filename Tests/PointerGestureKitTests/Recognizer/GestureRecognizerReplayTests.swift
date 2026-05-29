import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerReplayTests: XCTestCase {
  func testUnmatchedGestureRequestsButtonDragReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
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

    let down = makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    _ = eventSource.send(down)

    let drag = makeGestureInputEvent(
      kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
    XCTAssertEqual(eventSource.send(drag), .consume)

    let up = makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    XCTAssertEqual(eventSource.send(up), .consume)

    XCTAssertEqual(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [.init(x: 10, y: 10), .init(x: 100, y: 10), .init(x: 120, y: 10)]
        )
      ]
    )
  }

  func testUnmatchedPrimaryButtonGestureRequestsPrimaryButtonDragReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        recognitionButton: .primary,
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
      makeGestureInputEvent(kind: .buttonDown(.primary), location: .init(x: 10, y: 10))
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.primary), location: .init(x: 100, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.primary), location: .init(x: 120, y: 10))
      ),
      .consume
    )

    XCTAssertEqual(
      replayRequests,
      [
        .drag(
          button: .primary,
          points: [.init(x: 10, y: 10), .init(x: 100, y: 10), .init(x: 120, y: 10)]
        )
      ]
    )
  }

  func testIncompletePatternRequestsButtonDragReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: UUID())
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

    let down = makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    _ = eventSource.send(down)

    let drag = makeGestureInputEvent(
      kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
    XCTAssertEqual(eventSource.send(drag), .consume)

    let up = makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    XCTAssertEqual(eventSource.send(up), .consume)

    XCTAssertEqual(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [.init(x: 10, y: 10), .init(x: 100, y: 10), .init(x: 120, y: 10)]
        )
      ]
    )
  }

  func testEqualAxisDragStaysPendingUntilButtonDragReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 40, y: 40))),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [])

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 40))),
      .consume
    )

    XCTAssertEqual(
      replayRequests,
      [.drag(button: .secondary, points: [.zero, .init(x: 40, y: 40)])]
    )
  }

  func testDominantDragAfterEqualAxisDragRequestsButtonReleaseReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let matchedID = UUID()
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: matchedID)
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
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 40, y: 40))),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 80, y: 40))),
      .consume
    )
    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 100, y: 40))),
      .consume
    )
    XCTAssertEqual(replayRequests, [.release(button: .secondary, at: .init(x: 100, y: 40))])
  }

  func testInvalidGestureUpdatesClickReplayPointBeforeReplay() {
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

    for event in [
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10)),
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 10, y: 60)),
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 10, y: 80)),
    ] {
      _ = eventSource.send(event)
    }
    let result = eventSource.send(
      makeGestureInputEvent(
        kind: .buttonUp(.secondary),
        location: .init(x: 10, y: 100)
      ))

    XCTAssertEqual(result, .consume)
    XCTAssertEqual(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [
            .init(x: 10, y: 10), .init(x: 10, y: 60), .init(x: 10, y: 80),
            .init(x: 10, y: 100),
          ]
        )
      ]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }
}
