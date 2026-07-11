import Foundation
import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerSessionExpirationTests: XCTestCase {
  private static let shortExpirationTimeout: TimeInterval = 0.03
  private static let completedGestureExpirationDuration: TimeInterval = 0.03

  func testActiveSessionExpirationRequestsReleaseAndClearsTrace() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        makeMatcher: { _ in Self.makeRightGestureMatcher() },
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 10))
    )

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
        && !recognizer.snapshot.status.isCapturingGesture
    }

    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 30, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testUnmatchedStoppedSessionReplaysDragStartWithoutWaitingForExpiration() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 10))
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.directions.isEmpty)

    await XCTAssertNotEventually(timeout: Self.shortExpirationTimeout) {
      recognizer.snapshot.status.lastFailure != nil
    }

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    assertReplayRequests(
      replayRequests,
      [.dragStart(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 30, y: 10)])]
    )
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testPendingButtonInputExpirationReplaysClickAndClearsInput() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
        && replayRequests == [.click(button: .secondary, at: .init(x: 10, y: 10))]
    }

    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 10))
      ),
      .passThrough
    )
    assertReplayRequests(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
  }

  func testMovedPendingButtonInputBelowStartDistanceExpirationReplaysClickAndClearsInput() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        minimumGestureStartAxisDistance: 20,
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 19, y: 10))
      ),
      .consume
    )

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
        && replayRequests == [.click(button: .secondary, at: .init(x: 10, y: 10))]
    }

    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 10))
      ),
      .passThrough
    )
    assertReplayRequests(
      replayRequests,
      [.click(button: .secondary, at: .init(x: 10, y: 10))]
    )
  }

  func testSuccessfulGestureStartClearsStaleSessionExpirationFailure() async {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        makeMatcher: { _ in Self.makeRightGestureMatcher() }
      )
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 10))
    )

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
    }

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 40, y: 10))
      ),
      .consume
    )
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
  }

  func testNilMaximumGestureSessionDurationDisablesSessionExpiration() async {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        makeMatcher: { _ in Self.makeRightGestureMatcher() },
        maximumGestureSessionDuration: nil
      )
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 10))
    )

    await XCTAssertNotEventually(timeout: Self.shortExpirationTimeout) {
      recognizer.snapshot.status.lastFailure != nil
        || !recognizer.snapshot.status.isCapturingGesture
    }

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
  }

  func testCompletedGestureCancelsPendingSessionExpiration() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        makeMatcher: { _ in Self.makeRightGestureMatcher() },
        maximumGestureSessionDuration: Self.completedGestureExpirationDuration,
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 10))
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 30, y: 10))
      ),
      .consume
    )

    await XCTAssertNotEventually(timeout: Self.completedGestureExpirationTimeout) {
      recognizer.snapshot.status.lastFailure != nil
    }

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    assertReplayRequests(
      replayRequests,
      [.release(button: .secondary, at: .init(x: 30, y: 10))]
    )
  }

  func testStoppingRecognizerCancelsPendingSessionExpiration() async {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration()
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 30, y: 10))
    )

    recognizer.stop()
    await XCTAssertNotEventually(timeout: Self.shortExpirationTimeout) {
      recognizer.snapshot.status.lastFailure != nil
        || recognizer.snapshot.status.isCapturingGesture
    }

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  private func makeSessionExpirationConfiguration(
    makeMatcher:
      @escaping @MainActor @Sendable (GestureRecognitionContext?) -> GesturePatternMatcher<UUID> =
      { _ in GesturePatternMatcher<UUID>() },
    maximumGestureSessionDuration: TimeInterval? = 0.01,
    minimumGestureStartAxisDistance: Double = 0,
    onReplayRequested: @escaping @MainActor @Sendable (GestureReplayRequest) -> Void = { _ in }
  ) -> GestureRecognizerConfiguration<UUID> {
    makeGestureRecognizerTestConfiguration(
      makeMatcher: makeMatcher,
      onReplayRequested: onReplayRequested,
      areModifiersSatisfied: { _, _ in true },
      tuning: .testing(
        minimumGestureStartAxisDistance: minimumGestureStartAxisDistance,
        minimumDirectionChangeAxisDistance: 0,
        maximumGestureSessionDuration: maximumGestureSessionDuration
      )
    )
  }

  private static func makeRightGestureMatcher() -> GesturePatternMatcher<UUID> {
    var matcher = GesturePatternMatcher<UUID>()
    matcher.register(pattern: [.right], match: UUID())
    return matcher
  }

  private static var completedGestureExpirationTimeout: TimeInterval {
    completedGestureExpirationDuration * 2
  }
}
