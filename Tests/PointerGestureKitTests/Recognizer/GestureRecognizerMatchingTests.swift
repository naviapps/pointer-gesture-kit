import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerMatchingTests: XCTestCase {
  func testEmptyMatcherPassesThroughRecognitionButtonInput() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration(passesThroughEmptyMatcher: true)
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .passThrough
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
      ),
      .passThrough
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 10))
      ),
      .passThrough
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.directions.isEmpty)
  }

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
          case .drag, .dragStart:
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
      kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    assertDisposition(eventSource.send(drag), .consume)

    let up = makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    let result = eventSource.send(up)

    assertDisposition(result, .consume)
    XCTAssertEqual(calledIDs, [matchedID])
    XCTAssertEqual(clickRequestCount, 0)
    XCTAssertEqual(releaseRequests, [.init(x: 120, y: 10)])
  }

  func testMatchedGestureRequestsReplayBeforeMatchCallback() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let matchedID = UUID()
    var callbacks: [String] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: matchedID)
          return matcher
        },
        onReplayRequested: { _ in callbacks.append("replay") },
        onMatch: { _ in callbacks.append("match") },
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
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
      ),
      .consume
    )

    XCTAssertEqual(callbacks, ["replay", "match"])
  }

  func testRecognitionSessionKeepsReleaseOnlyReplayWhenRecordingModeIsEnabledMidGesture() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let matchedID = UUID()
    var calledIDs: [UUID] = []
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: matchedID)
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    )

    recognizer.isRecordingModeEnabled = true

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    )

    XCTAssertEqual(calledIDs, [matchedID])
    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 120, y: 10))])
  }

  func testFirstDirectionUsesGestureStartThreshold() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let matchedID = UUID()
    var calledIDs: [UUID] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: matchedID)
          return matcher
        },
        onMatch: { calledIDs.append($0) },
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 21, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 21, y: 10))
      ),
      .consume
    )

    XCTAssertEqual(calledIDs, [matchedID])
  }

  func testMovementWithoutDominantAxisDoesNotStartGesture() {
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
          minimumGestureStartAxisDistance: 10,
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
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 30))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 30, y: 30))
      ),
      .consume
    )

    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertTrue(recognizer.snapshot.trace.directions.isEmpty)
    assertReplayRequests(
      replayRequests,
      [
        .drag(
          button: .secondary,
          points: [
            .init(x: 10, y: 10),
            .init(x: 30, y: 30),
          ]
        )
      ]
    )
  }

  func testRegisteringSamePatternUsesLatestMatch() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let firstID = UUID()
    let secondID = UUID()
    var calledIDs: [UUID] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: firstID)
          matcher.register(pattern: [.right], match: secondID)
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    )

    XCTAssertEqual(calledIDs, [secondID])
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    )
    assertDisposition(
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
      ),
      .consume
    )

    XCTAssertTrue(calledIDs.isEmpty)
  }

  func testDirectionChangeAtMinimumDistanceCompletesRegisteredPattern() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let matchedID = UUID()
    var calledIDs: [UUID] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: matchedID)
          return matcher
        },
        onMatch: { calledIDs.append($0) },
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
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 0))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 25))
      ),
      .consume
    )

    XCTAssertTrue(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right, .down])

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 25))
      ),
      .consume
    )
    XCTAssertEqual(calledIDs, [matchedID])
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 100))
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
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 100, y: -80))
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [])
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 140, y: -100))
      ),
      .passThrough
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [])
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 160, y: -100))
      ),
      .passThrough
    )

    XCTAssertTrue(calledIDs.isEmpty)
    assertReplayRequests(
      replayRequests,
      [
        .dragStart(
          button: .secondary,
          points: [
            .init(x: 10, y: 10),
            .init(x: 100, y: 10),
            .init(x: 100, y: -80),
          ]
        )
      ]
    )
  }
}

@MainActor
private final class MatchingSnapshotProbe {
  var recognizer: GestureRecognizer<UUID>?
  var snapshot: GestureRecognizerState?

  func record() {
    snapshot = recognizer?.snapshot
  }
}
