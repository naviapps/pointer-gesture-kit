import XCTest

import PointerGestureKit

@MainActor
final class PointerGestureKitPublicAPITests: XCTestCase {
  func testCoreRecognizerAndMatchingAPIsAreUsableFromPublicImport() throws {
    var matcher = GesturePatternMatcher<PublicGestureCommand>()
    var emptyMatcher: GesturePatternMatcher<PublicGestureCommand> = .init()
    let registerResult = matcher.register(pattern: [.down, .right], match: .showInspector)
    let emptyRegisterResult = emptyMatcher.register(pattern: [], match: .showInspector)

    let context = try XCTUnwrap(GestureRecognitionContext(identifier: " editor "))
    let tuning = try GestureRecognizerTuning.validated(
      minimumGestureStartAxisDistance: 6,
      minimumDirectionChangeAxisDistance: 4,
      maximumGestureSessionDuration: 1,
      maximumRawPointCount: 32,
      eventSourceStartRetryDelays: []
    )
    let configuration = GestureRecognizerConfiguration<PublicGestureCommand>.init(
      makeMatcher: { receivedContext in
        XCTAssertEqual(receivedContext, context)
        return matcher
      },
      onReplayRequested: { _ in },
      onMatch: { _ in },
      recognitionButton: .secondary,
      recognitionContext: { _ in context },
      isRecognitionEnabled: { $0 == context },
      passesThroughEmptyMatcher: true,
      areModifiersSatisfied: { modifiers, _ in modifiers.contains(.command) },
      tuning: tuning
    )
    let recognizer = GestureRecognizer(
      eventSource: PublicGestureEventSource(),
      configuration: configuration
    )
    recognizer.isRecordingModeEnabled = true
    let duplicateTuningUpdateResult: Bool = recognizer.updateTuning(tuning)
    recognizer.retryStartNow()
    recognizer.cancelActiveGesture()

    let state: GestureRecognizerState = recognizer.snapshot
    let trace: GestureRecognizerState.Trace = state.trace
    let lifecycle: GestureRecognizerState.Status.Lifecycle = .idle
    let failures: [GestureRecognizerFailure] = [
      .eventSourceStartFailed,
      .recognitionDisabled,
      .modifiersNotSatisfied,
      .gestureSessionExpired,
    ]
    let statusToken = recognizer.observeStatus { status in
      XCTAssertEqual(status.lifecycle, .idle)
    }
    let traceToken = recognizer.observeTrace { trace in
      XCTAssertFalse(trace.isVisible)
    }

    XCTAssertEqual(state.status.lifecycle, .idle)
    XCTAssertEqual(lifecycle, state.status.lifecycle)
    XCTAssertNotEqual(state.status.lifecycle, .starting)
    XCTAssertNotEqual(state.status.lifecycle, .ready)
    XCTAssertNotEqual(state.status.lifecycle, .retrying)
    XCTAssertNotEqual(state.status.lifecycle, .failed)
    XCTAssertFalse(state.status.isCapturingGesture)
    XCTAssertTrue(state.status.isRecordingModeEnabled)
    XCTAssertEqual(state.status.lastRecordedDirections, [])
    XCTAssertNil(state.status.lastFailure)
    XCTAssertTrue(registerResult)
    XCTAssertFalse(emptyRegisterResult)
    XCTAssertFalse(duplicateTuningUpdateResult)
    XCTAssertNil(emptyMatcher.match(pattern: []))
    XCTAssertFalse(trace.isVisible)
    XCTAssertEqual(trace.rawPoints, [])
    XCTAssertEqual(trace.directions, [])
    XCTAssertEqual(trace.directionEndpoints, [])
    XCTAssertNil(trace.tailPoint)
    XCTAssertEqual(tuning.minimumGestureStartAxisDistance, 6)
    XCTAssertEqual(tuning.minimumDirectionChangeAxisDistance, 4)
    XCTAssertEqual(tuning.maximumGestureSessionDuration, 1)
    XCTAssertEqual(tuning.maximumRawPointCount, 32)
    XCTAssertEqual(tuning.eventSourceStartRetryDelays, [])
    XCTAssertEqual(context.identifier, "editor")
    XCTAssertTrue(failures.contains(.recognitionDisabled))
    statusToken.cancel()
    traceToken.cancel()
  }

  func testCoreValueAPIsAreUsableFromPublicImport() {
    let point = GesturePoint(x: .infinity, y: 12)
    let input = GestureInputEvent(
      kind: .buttonDown(.secondary),
      location: point,
      modifiers: [.command, .shift]
    )
    let inputKind: GestureInputEvent.Kind = .cancel
    let direction: GestureDirection = .up
    let modifiers: GestureModifierFlags = [.command, .option, .control, .shift]
    let emptyModifiers = GestureModifierFlags(rawValue: 0)
    let normalizedModifiers = GestureModifierFlags(
      rawValue: GestureModifierFlags.command.rawValue | (1 << 20)
    )

    XCTAssertEqual(point.x, .infinity)
    XCTAssertFalse(point.isFinite)
    XCTAssertEqual(point.y, 12)
    XCTAssertEqual(input.kind, .buttonDown(.secondary))
    XCTAssertEqual(
      GestureInputEvent.Kind.buttonMoved(.secondary),
      .buttonMoved(.secondary)
    )
    XCTAssertEqual(GestureInputEvent.Kind.buttonUp(.secondary), .buttonUp(.secondary))
    XCTAssertEqual(inputKind, .cancel)
    XCTAssertEqual(direction, .up)
    XCTAssertTrue(input.modifiers.contains(.command))
    XCTAssertTrue(modifiers.contains(.option))
    XCTAssertTrue(modifiers.contains(.control))
    XCTAssertTrue(modifiers.contains(.shift))
    XCTAssertEqual(emptyModifiers.rawValue, 0)
    XCTAssertEqual(
      normalizedModifiers.rawValue,
      GestureModifierFlags.command.rawValue | (1 << 20)
    )
    XCTAssertEqual(PointerButton.primary.auxiliaryButtonID, nil)
    XCTAssertEqual(PointerButton.secondary.auxiliaryButtonID, nil)
    XCTAssertEqual(PointerButton.middle.auxiliaryButtonID, nil)
    XCTAssertEqual(PointerButton(auxiliaryButtonID: 4)?.auxiliaryButtonID, 4)
    XCTAssertEqual(GestureEventDisposition.consume.consumesOriginalEvent, true)
    XCTAssertEqual(GestureEventDisposition.passThrough.consumesOriginalEvent, false)
    XCTAssertEqual(
      GestureReplayRequest.click(button: .secondary, at: .zero),
      .click(button: .secondary, at: .zero)
    )
    XCTAssertEqual(
      GestureReplayRequest.drag(button: .secondary, points: [.zero, point]),
      .drag(button: .secondary, points: [.zero, point])
    )
    XCTAssertEqual(
      GestureReplayRequest.release(button: .secondary, at: point),
      .release(button: .secondary, at: point)
    )
  }

  func testObservationTokenAPIIsUsableFromPublicImport() {
    let token: GestureObservationToken = PublicObservationSource().observe()

    token.cancel()
  }

  func testRecognizerSnapshotValuesAreConstructibleFromPublicImport() {
    let status = GestureRecognizerState.Status(
      lifecycle: .ready,
      isCapturingGesture: true,
      isRecordingModeEnabled: true,
      lastRecordedDirections: [.up, .right],
      lastFailure: .modifiersNotSatisfied
    )
    let trace = GestureRecognizerState.Trace(
      isVisible: true,
      rawPoints: [.zero, GesturePoint(x: 12, y: 24)],
      directions: [.up],
      directionEndpoints: [.zero, GesturePoint(x: 0, y: -20)],
      tailPoint: GesturePoint(x: 12, y: 24)
    )
    let partialTrace = GestureRecognizerState.Trace(
      rawPoints: [.zero, GesturePoint(x: 12, y: 0), GesturePoint(x: 12, y: 24)],
      directions: [.right, .down],
      directionEndpoints: [.zero]
    )
    let state = GestureRecognizerState(status: status, trace: trace)

    XCTAssertEqual(state.status.lifecycle, .ready)
    XCTAssertTrue(state.status.isCapturingGesture)
    XCTAssertTrue(state.status.isRecordingModeEnabled)
    XCTAssertEqual(state.status.lastRecordedDirections, [.up, .right])
    XCTAssertEqual(state.status.lastFailure, .modifiersNotSatisfied)
    XCTAssertTrue(state.trace.isVisible)
    XCTAssertEqual(state.trace.rawPoints, [.zero, GesturePoint(x: 12, y: 24)])
    XCTAssertEqual(state.trace.directions, [.up])
    XCTAssertEqual(state.trace.directionEndpoints, [.zero, GesturePoint(x: 0, y: -20)])
    XCTAssertEqual(state.trace.tailPoint, GesturePoint(x: 12, y: 24))
    XCTAssertEqual(
      partialTrace.directionEndpoints,
      [.zero]
    )
  }

  func testDocumentationExamplesAreUsableWithoutTestableImport() {
    var matcher = GesturePatternMatcher<PublicGestureCommand>()
    matcher.register(pattern: [.down, .right], match: .showInspector)
    matcher.register(pattern: [.up, .left], match: .focusSearch)

    let recognizer = GestureRecognizer(
      eventSource: PublicGestureEventSource(),
      configuration: GestureRecognizerConfiguration<PublicGestureCommand>(
        makeMatcher: { _ in matcher },
        onReplayRequested: { _ in },
        onMatch: { _ in },
        areModifiersSatisfied: { modifiers, _ in
          modifiers.contains(.command)
        }
      )
    )
    let traceToken = recognizer.observeTrace { trace in
      renderTrace(
        isVisible: trace.isVisible,
        points: trace.rawPoints,
        directions: trace.directions,
        directionEndpoints: trace.directionEndpoints,
        tailPoint: trace.tailPoint
      )
    }

    XCTAssertEqual(matcher.match(pattern: [.down, .right]), .showInspector)
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    traceToken.cancel()
  }

}

private enum PublicGestureCommand: Sendable {
  case showInspector
  case focusSearch
}

@MainActor
private final class PublicGestureEventSource: GestureEventSource {
  func start(
    handler: @escaping @MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition
  ) -> Bool {
    _ = handler
    return true
  }

  func stop() {}
}

@MainActor
private final class PublicObservationSource {
  func observe() -> GestureObservationToken {
    GestureRecognizer(
      eventSource: PublicGestureEventSource(),
      configuration: GestureRecognizerConfiguration<PublicGestureCommand>(
        makeMatcher: { _ in GesturePatternMatcher<PublicGestureCommand>() },
        onReplayRequested: { _ in },
        onMatch: { _ in }
      )
    )
    .observe { _ in }
  }
}

@MainActor
private func renderTrace(
  isVisible: Bool,
  points: [GesturePoint],
  directions: [GestureDirection],
  directionEndpoints: [GesturePoint],
  tailPoint: GesturePoint?
) {
  _ = isVisible
  _ = points
  _ = directions
  _ = directionEndpoints
  _ = tailPoint
}
