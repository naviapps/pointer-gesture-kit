import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerMatchingTests: XCTestCase {
  func testMatchCallsOnMatchAndConsumesButtonUp() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var releaseRequests: [GesturePoint] = []

    let matchedID = UUID()
    let makeMatcher: @MainActor (GestureRecognitionContext?) -> GesturePatternMatcher<UUID> = {
      _ in
      var matcher = GesturePatternMatcher<UUID>()
      matcher.register(pattern: [.right], match: matchedID)
      return matcher
    }

    var calledIDs: [UUID] = []
    var clickRequestCount = 0
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: makeMatcher,
        onReplayRequested: { request in
          switch request {
          case .click:
            clickRequestCount += 1
          case .drag:
            XCTFail("Matched gestures should not replay the consumed sequence.")
          case let .release(_, point):
            releaseRequests.append(point)
          }
        },
        onMatch: { calledIDs.append($0) },
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
    let result = eventSource.send(up)

    XCTAssertEqual(result, .consume)
    XCTAssertEqual(calledIDs, [matchedID])
    XCTAssertEqual(clickRequestCount, 0)
    XCTAssertEqual(releaseRequests, [.init(x: 120, y: 10)])
  }

  func testMatchCallbackReceivesCompletedSnapshot() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let matchedID = UUID()
    let snapshotProbe = MatchingSnapshotProbe()

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: matchedID)
          return matcher
        },
        onMatch: { _ in
          snapshotProbe.record()
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
    snapshotProbe.recognizer = recognizer

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
      ),
      .consume
    )

    XCTAssertEqual(snapshotProbe.snapshot?.status.lastRecordedDirections, [.right])
    XCTAssertEqual(snapshotProbe.snapshot?.status.isCapturingGesture, false)
    XCTAssertEqual(snapshotProbe.snapshot?.trace.isVisible, false)
  }

  func testIncompletePatternDoesNotCallOnMatch() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var calledIDs: [UUID] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: UUID())
          return matcher
        },
        onMatch: { calledIDs.append($0) },
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
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
      ),
      .consume
    )

    XCTAssertTrue(calledIDs.isEmpty)
  }

  func testShortSharedPrefixPatternMatchesWhenGestureEndsAtPrefix() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let shortID = UUID()
    let longID = UUID()
    var calledIDs: [UUID] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: shortID)
          matcher.register(pattern: [.right, .down], match: longID)
          return matcher
        },
        onMatch: { calledIDs.append($0) },
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    )

    XCTAssertEqual(calledIDs, [shortID])
  }

  func testLongSharedPrefixPatternMatchesWhenGestureContinuesPastPrefix() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let shortID = UUID()
    let longID = UUID()
    var calledIDs: [UUID] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: shortID)
          matcher.register(pattern: [.right, .down], match: longID)
          return matcher
        },
        onMatch: { calledIDs.append($0) },
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: 100))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 100, y: 120))
    )

    XCTAssertEqual(calledIDs, [longID])
  }

  func testBranchMismatchAfterRegisteredPrefixDoesNotCallOnMatch() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var calledIDs: [UUID] = []
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: UUID())
          return matcher
        },
        onReplayRequested: { replayRequests.append($0) },
        onMatch: { calledIDs.append($0) },
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 100, y: -80))
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 100, y: -100))
      ),
      .consume
    )

    XCTAssertTrue(calledIDs.isEmpty)
    XCTAssertEqual(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [
            .init(x: 10, y: 10),
            .init(x: 100, y: 10),
            .init(x: 100, y: -80),
            .init(x: 100, y: -100),
          ]
        )
      ]
    )
  }
}

@MainActor
private final class MatchingSnapshotProbe: @unchecked Sendable {
  var recognizer: GestureRecognizer<UUID>?
  var snapshot: GestureRecognizerState?

  func record() {
    snapshot = recognizer?.snapshot
  }
}
