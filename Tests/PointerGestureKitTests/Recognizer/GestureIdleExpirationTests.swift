import XCTest

@testable import PointerGestureKit

final class GestureIdleExpirationTests: XCTestCase {
  @MainActor
  func testPromotionPreservesTheButtonInputTotalDeadline() throws {
    let source = GestureEventSourceDouble(startResult: true)
    let recognizer = GestureRecognizer<UUID>(
      eventSource: source,
      configuration: makeGestureRecognizerTestConfiguration(
        tuning: try .validated(maximumGestureSessionDuration: 15, maximumGestureIdleDuration: 1)))
    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    let originalStart = ContinuousClock.now.advanced(by: .milliseconds(-500))
    recognizer.pendingButtonInput?.timing = GestureInputTiming(now: originalStart)
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
    XCTAssertEqual(recognizer.session?.timing.startedAt, originalStart)
    recognizer.stop()
  }

  @MainActor
  func testExpiredActiveInputCannotMatchBeforeTheExpirationTaskGetsToRun() throws {
    let source = GestureEventSourceDouble(startResult: true)
    var matcher = GesturePatternMatcher<UUID>()
    matcher.register(pattern: [.right], match: UUID())
    var matches = 0
    let recognizer = GestureRecognizer<UUID>(
      eventSource: source,
      configuration: makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in matcher }, onMatch: { _ in matches += 1 },
        tuning: try .validated(maximumGestureSessionDuration: 1)))
    recognizer.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
    recognizer.session?.timing = GestureInputTiming(now: .now.advanced(by: .seconds(-2)))
    _ = source.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 0)))
    XCTAssertEqual(matches, 0)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    XCTAssertNil(recognizer.session)
    recognizer.stop()
  }

  @MainActor
  func testExpiredPendingInputCannotPromoteBeforeTheExpirationTaskGetsToRun() throws {
    let source = GestureEventSourceDouble(startResult: true)
    let recognizer = GestureRecognizer<UUID>(
      eventSource: source,
      configuration: makeGestureRecognizerTestConfiguration(
        tuning: try .validated(maximumGestureSessionDuration: 1)))
    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    recognizer.pendingButtonInput?.timing = GestureInputTiming(now: .now.advanced(by: .seconds(-2)))
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .gestureSessionExpired)
    XCTAssertNil(recognizer.session)
    recognizer.stop()
  }

  func testIdleDurationRejectsNonPositiveAndNonFiniteValues() {
    for value: Double in [0, -1, .nan, .infinity, -.infinity] {
      XCTAssertThrowsError(try GestureRecognizerTuning.validated(maximumGestureIdleDuration: value))
      {
        XCTAssertEqual(
          $0 as? GestureRecognizerTuning.ValidationError, .invalidMaximumGestureIdleDuration)
      }
    }
    XCTAssertNil(GestureRecognizerTuning.standard.maximumGestureIdleDuration)
  }

  func testMovementExtendsIdleDeadlineWithoutExtendingTotalDeadline() throws {
    let start = ContinuousClock.now
    var timing = GestureInputTiming(now: start)
    let tuning = try GestureRecognizerTuning.validated(
      maximumGestureSessionDuration: 15, maximumGestureIdleDuration: 1)
    for second in 1...14 {
      let now = start.advanced(by: .seconds(second))
      timing.noteMovement(now: now)
      XCTAssertEqual(timing.remainingDuration(tuning: tuning, now: now), 1)
    }
    timing.noteMovement(now: start.advanced(by: .seconds(15)))
    XCTAssertEqual(
      timing.remainingDuration(tuning: tuning, now: start.advanced(by: .seconds(15))), 0)
  }

  func testIdleOnlyAndDisabledTimingUseIndependentDeadlines() throws {
    let start = ContinuousClock.now
    var timing = GestureInputTiming(now: start)
    timing.noteMovement(now: start.advanced(by: .seconds(10)))
    let idle = try GestureRecognizerTuning.validated(
      maximumGestureSessionDuration: nil, maximumGestureIdleDuration: 2)
    XCTAssertEqual(timing.remainingDuration(tuning: idle, now: start.advanced(by: .seconds(11))), 1)
    XCTAssertEqual(timing.remainingDuration(tuning: idle, now: start.advanced(by: .seconds(12))), 0)
    XCTAssertNil(
      timing.remainingDuration(
        tuning: try .validated(maximumGestureSessionDuration: nil),
        now: start.advanced(by: .seconds(100))))
  }

  @MainActor
  func testMovementRefreshesActiveAndPendingTimingButStationaryEventsDoNot() throws {
    let source = GestureEventSourceDouble(startResult: true)
    let recognizer = GestureRecognizer<UUID>(
      eventSource: source,
      configuration: makeGestureRecognizerTestConfiguration(
        tuning: try .validated(maximumGestureSessionDuration: nil, maximumGestureIdleDuration: 1)))
    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    let old = ContinuousClock.now.advanced(by: .milliseconds(-1))
    recognizer.pendingButtonInput?.timing = GestureInputTiming(now: old)
    _ = source.send(makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .zero))
    XCTAssertEqual(recognizer.pendingButtonInput?.timing.lastMovementAt, old)
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 1, y: 0)))
    XCTAssertGreaterThan(try XCTUnwrap(recognizer.pendingButtonInput?.timing.lastMovementAt), old)
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
    recognizer.session?.timing = GestureInputTiming(now: old)
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
    XCTAssertEqual(recognizer.session?.timing.lastMovementAt, old)
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 21, y: 0)))
    XCTAssertGreaterThan(try XCTUnwrap(recognizer.session?.timing.lastMovementAt), old)
    recognizer.stop()
  }

  @MainActor
  func testIdleOnlyTimerExpiresPendingAndActiveInputWithOriginalReplay() async throws {
    for active in [false, true] {
      let source = GestureEventSourceDouble(startResult: true)
      var replays: [GestureReplayRequest] = []
      var matches = 0
      var matcher = GesturePatternMatcher<UUID>()
      matcher.register(pattern: [.right], match: UUID())
      let recognizer = GestureRecognizer<UUID>(
        eventSource: source,
        configuration: makeGestureRecognizerTestConfiguration(
          makeMatcher: { [matcher] _ in matcher }, onReplayRequested: { replays.append($0) },
          onMatch: { _ in matches += 1 },
          tuning: try .validated(
            maximumGestureSessionDuration: nil, maximumGestureIdleDuration: 0.01)))
      recognizer.start()
      _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
      if active {
        _ = source.send(
          makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
      }
      await XCTAssertEventually(timeout: 1) {
        recognizer.snapshot.status.lastFailure == .gestureSessionExpired
      }
      XCTAssertEqual(matches, 0)
      assertReplayRequests(
        replays,
        [
          active
            ? .release(button: .secondary, at: .init(x: 20, y: 0))
            : .click(button: .secondary, at: .zero)
        ])
      XCTAssertNil(recognizer.session)
      XCTAssertNil(recognizer.pendingButtonInput)
      XCTAssertFalse(recognizer.snapshot.trace.isVisible)
      assertDisposition(
        source.send(makeGestureInputEvent(kind: .buttonUp(.secondary), location: .zero)),
        .passThrough)
      recognizer.stop()
    }
  }

  @MainActor
  func testDisablingIdleExpirationCancelsOldDeadlineAndStillCompletesMatch() async throws {
    let source = GestureEventSourceDouble(startResult: true)
    var matcher = GesturePatternMatcher<UUID>()
    matcher.register(pattern: [.right], match: UUID())
    var matches = 0
    let recognizer = GestureRecognizer<UUID>(
      eventSource: source,
      configuration: makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in matcher }, onMatch: { _ in matches += 1 },
        tuning: try .validated(
          maximumGestureSessionDuration: nil, maximumGestureIdleDuration: 0.01)))
    recognizer.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    _ = source.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0)))
    recognizer.updateTuning(try .validated(maximumGestureSessionDuration: nil))
    await XCTAssertNotEventually(timeout: 0.03) {
      recognizer.snapshot.status.lastFailure != nil
    }
    _ = source.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 0)))
    XCTAssertEqual(matches, 1)
    recognizer.stop()
  }

  @MainActor
  func testCancelStopAndReleaseDoNotLeaveAnIdleExpirationOrRetainRecognizer() async throws {
    let source = GestureEventSourceDouble(startResult: true)
    var replayCount = 0
    var recognizer: GestureRecognizer<UUID>? = GestureRecognizer<UUID>(
      eventSource: source,
      configuration: makeGestureRecognizerTestConfiguration(
        onReplayRequested: { _ in replayCount += 1 },
        tuning: try .validated(
          maximumGestureSessionDuration: nil, maximumGestureIdleDuration: 0.01)))
    recognizer?.isRecordingModeEnabled = true
    recognizer?.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    recognizer?.cancelActiveGesture()
    XCTAssertEqual(replayCount, 1)
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    recognizer?.stop()
    XCTAssertEqual(replayCount, 2)
    await XCTAssertNotEventually(timeout: 0.03) { replayCount != 2 }
    weak var weakRecognizer = recognizer
    recognizer?.start()
    _ = source.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    recognizer = nil
    XCTAssertNil(weakRecognizer)
    weakRecognizer = nil
    XCTAssertEqual(replayCount, 3)
    await XCTAssertNotEventually(timeout: 0.03) { replayCount != 3 }
  }
}
