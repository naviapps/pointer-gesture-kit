import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerReplayTests: XCTestCase {
  func testStoppedUnmatchedGestureReplaysConsumedDragStartAndReleasesSession() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.left], match: UUID())
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
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
      ),
      .consume
    )

    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .secondary,
          points: [.init(x: 10, y: 10), .init(x: 40, y: 10)]
        )
      ]
    )

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 45, y: 10))
      ),
      .passThrough
    )
    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .secondary,
          points: [.init(x: 10, y: 10), .init(x: 40, y: 10)]
        )
      ]
    )
  }

  func testUnmatchedGestureRequestsDragStartReplay() {
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
      kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    assertDisposition(eventSource.send(drag), .consume)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)

    let up = makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    assertDisposition(eventSource.send(up), .passThrough)

    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .secondary,
          points: [.init(x: 10, y: 10), .init(x: 100, y: 10)]
        )
      ]
    )
  }

  func testUnmatchedGestureReleasesSessionAfterDragStartReplay() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0,
          maximumRawPointCount: 3
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 0, y: 0))
    )

    for point in [
      GesturePoint(x: 20, y: 0),
      GesturePoint(x: 40, y: 0),
      GesturePoint(x: 60, y: 0),
      GesturePoint(x: 80, y: 0),
    ] {
      assertDisposition(
        eventSource.send(makeGestureInputEvent(kind: .buttonMoved(.secondary), location: point)),
        point == GesturePoint(x: 20, y: 0) ? .consume : .passThrough
      )
    }
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 100, y: 0))
      ),
      .passThrough
    )

    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .secondary,
          points: [.init(x: 0, y: 0), .init(x: 20, y: 0)]
        )
      ]
    )
  }

  func testUnmatchedPrimaryButtonGestureRequestsPrimaryButtonDragStartReplay() {
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.primary), location: .init(x: 100, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.primary), location: .init(x: 120, y: 10))
      ),
      .passThrough
    )

    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .primary,
          points: [.init(x: 10, y: 10), .init(x: 100, y: 10)]
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
      kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    assertDisposition(eventSource.send(drag), .consume)

    let up = makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    assertDisposition(eventSource.send(up), .consume)

    assertReplayRequests(
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 40))),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [])

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 40))),
      .consume
    )

    assertReplayRequests(
      replayRequests,
      [.drag(button: .secondary, points: [.zero, .init(x: 40, y: 40)])]
    )
  }

  func testPendingButtonDragReplayRetainsStartAndRecentPointsWithinRawPointLimit() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 50,
          minimumDirectionChangeAxisDistance: 0,
          maximumRawPointCount: 3
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

    for point in [
      GesturePoint(x: 20, y: 20),
      GesturePoint(x: 40, y: 40),
      GesturePoint(x: 60, y: 60),
      GesturePoint(x: 80, y: 80),
    ] {
      assertDisposition(
        eventSource.send(makeGestureInputEvent(kind: .buttonMoved(.secondary), location: point)),
        .consume
      )
    }
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 90, y: 90))
      ),
      .consume
    )

    assertReplayRequests(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [.zero, .init(x: 80, y: 80), .init(x: 90, y: 90)]
        )
      ]
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 40))),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 80, y: 40))),
      .consume
    )
    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 100, y: 40))),
      .consume
    )
    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 100, y: 40))])
  }

  func testInvalidGestureRequestsDragStartReplayBeforeFurtherInput() {
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 60)),
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 80)),
    ] {
      _ = eventSource.send(event)
    }
    let result = eventSource.send(
      makeGestureInputEvent(
        kind: .buttonUp(.secondary),
        location: .init(x: 10, y: 100)
      ))

    assertDisposition(result, .passThrough)
    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .secondary,
          points: [
            .init(x: 10, y: 10), .init(x: 10, y: 60),
          ]
        )
      ]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }
}
