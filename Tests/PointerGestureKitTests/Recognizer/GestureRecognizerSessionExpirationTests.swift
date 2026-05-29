import Foundation
import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerSessionExpirationTests: XCTestCase {
  private static let shortExpirationSleepNanoseconds: UInt64 = 30_000_000
  private static let completedGestureExpirationDuration: TimeInterval = 0.03
  private static let completedGestureExpirationSleepNanoseconds: UInt64 = 60_000_000

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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 10))
    )

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
        && !recognizer.snapshot.status.isCapturingGesture
    }

    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    XCTAssertEqual(replayRequests, [.release(button: .secondary, at: .init(x: 30, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testStoppedSessionExpirationReplaysConsumedButtonInput() async {
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 10))
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
    }

    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    XCTAssertEqual(
      replayRequests,
      [.drag(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 30, y: 10)])]
    )
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.rawPoints.isEmpty)
  }

  func testPendingButtonInputDoesNotScheduleSessionExpiration() async throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )

    try await Task.sleep(nanoseconds: Self.shortExpirationSleepNanoseconds)

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertTrue(replayRequests.isEmpty)

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
  }

  func testSuccessfulGestureStartClearsStaleSessionExpirationFailure() async {
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 10))
    )

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lastFailure == .gestureSessionExpired
    }

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 40, y: 10))
      ),
      .consume
    )
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
  }

  func testNilMaximumGestureSessionDurationDisablesSessionExpiration() async throws {
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 10))
    )

    try await Task.sleep(nanoseconds: Self.shortExpirationSleepNanoseconds)

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
  }

  func testCompletedGestureCancelsPendingSessionExpiration() async throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeSessionExpirationConfiguration(
        maximumGestureSessionDuration: Self.completedGestureExpirationDuration,
        onReplayRequested: { replayRequests.append($0) }
      )
    )

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 10))
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 30, y: 10))
      ),
      .consume
    )

    try await Task.sleep(nanoseconds: Self.completedGestureExpirationSleepNanoseconds)

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(
      replayRequests,
      [.drag(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 30, y: 10)])]
    )
  }

  func testStoppingRecognizerCancelsPendingSessionExpiration() async throws {
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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 30, y: 10))
    )

    recognizer.stop()
    try await Task.sleep(nanoseconds: Self.shortExpirationSleepNanoseconds)

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  private func makeSessionExpirationConfiguration(
    makeMatcher:
      @escaping @MainActor @Sendable (GestureRecognitionContext?) -> GesturePatternMatcher<UUID> =
      { _ in GesturePatternMatcher<UUID>() },
    maximumGestureSessionDuration: TimeInterval? = 0.01,
    onReplayRequested: @escaping @MainActor @Sendable (GestureReplayRequest) -> Void = { _ in }
  ) -> GestureRecognizerConfiguration<UUID> {
    makeGestureRecognizerTestConfiguration(
      makeMatcher: makeMatcher,
      onReplayRequested: onReplayRequested,
      areModifiersSatisfied: { _, _ in true },
      tuning: .testing(
        minimumGestureStartAxisDistance: 0,
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
}
