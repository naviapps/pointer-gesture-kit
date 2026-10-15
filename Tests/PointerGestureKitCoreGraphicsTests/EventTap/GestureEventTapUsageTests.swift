import PointerGestureKit
import XCTest

@testable import PointerGestureKitCoreGraphics

@MainActor
final class GestureEventTapUsageTests: XCTestCase {
  func testSendableContractAcceptsEventTap() {
    let sendableEventTap: any Sendable = GestureEventTap()
    _ = sendableEventTap
  }

  func testStopIsIdempotentWhenTapIsNotStarted() {
    let eventTap = GestureEventTap()

    eventTap.stop()
    eventTap.stop()
  }

  func testStartReturnsFalseWhenCapturedButtonsAreEmpty() {
    let eventTap = GestureEventTap(capturedButtons: [])

    let didStart = eventTap.start { _ in .consume }

    XCTAssertFalse(didStart)
  }

  func testDisabledTapInputDispatchDeliversCancelSynchronouslyOnMainActor() {
    let inputDispatch = GestureEventTapInputDispatch()
    var handledKinds: [GestureInputEvent.Kind] = []
    inputDispatch.install { input in
      handledKinds.append(input.kind)
      return .consume
    }

    inputDispatch.recoverFromTapDisabled(
      input: GestureInputEvent(
        kind: .cancel,
        location: .zero,
        modifiers: []
      ),
      sourceSignature: .tapDisabledTimeout
    )

    XCTAssertEqual(handledKinds, [.cancel])
  }

  func testDisabledTapInputDispatchClearsSyntheticSuppressionBeforeDispatchingCancel() {
    let inputDispatch = GestureEventTapInputDispatch()
    var pendingCountsSeenByHandler: [Int] = []
    inputDispatch.install { [weak inputDispatch] input in
      guard let inputDispatch else { return .passThrough }
      XCTAssertEqual(input.kind, .cancel)
      pendingCountsSeenByHandler.append(inputDispatch.pendingSyntheticEventSignatureCount())
      inputDispatch.syntheticEventSuppression.suppress([
        .replayed(type: .leftMouseUp, button: .primary)
      ])
      return .consume
    }
    inputDispatch.syntheticEventSuppression.suppress([
      .replayed(type: .rightMouseUp, button: .secondary)
    ])

    inputDispatch.recoverFromTapDisabled(
      input: GestureInputEvent(
        kind: .cancel,
        location: .zero,
        modifiers: []
      ),
      sourceSignature: .tapDisabledTimeout
    )

    XCTAssertEqual(pendingCountsSeenByHandler, [0])
    XCTAssertEqual(inputDispatch.pendingSyntheticEventSignatureCount(), 1)
  }

  func testInputDispatchStopDropsHandlerAndPendingSyntheticEvents() {
    let inputDispatch = GestureEventTapInputDispatch()
    var handledKinds: [GestureInputEvent.Kind] = []
    inputDispatch.install { input in
      handledKinds.append(input.kind)
      return .consume
    }
    inputDispatch.syntheticEventSuppression.suppress([
      .replayed(type: .rightMouseUp, button: .secondary)
    ])

    inputDispatch.stop()
    let disposition = inputDispatch.dispatch(
      GestureInputEvent(kind: .cancel, location: .zero, modifiers: []),
      sourceSignature: .tapDisabledTimeout
    )

    XCTAssertEqual(disposition, .passThrough)
    XCTAssertTrue(handledKinds.isEmpty)
    XCTAssertEqual(inputDispatch.pendingSyntheticEventSignatureCount(), 0)
  }

  func testInputDispatchPassesThroughReplayedInputWithoutInvokingHandler() {
    let inputDispatch = GestureEventTapInputDispatch()
    var handledKinds: [GestureInputEvent.Kind] = []
    inputDispatch.install { input in
      handledKinds.append(input.kind)
      return .consume
    }
    let signature = SyntheticEventSignature.replayed(type: .rightMouseUp, button: .secondary)
    inputDispatch.syntheticEventSuppression.suppress([signature])

    let disposition = inputDispatch.dispatch(
      GestureInputEvent(kind: .buttonUp(.secondary), location: .zero, modifiers: []),
      sourceSignature: signature
    )

    XCTAssertEqual(disposition, .passThrough)
    XCTAssertTrue(handledKinds.isEmpty)
    XCTAssertEqual(inputDispatch.pendingSyntheticEventSignatureCount(), 0)
  }

  func testReadmeStyleDefaultButtonControllerTypeChecks() {
    let controller = ReadmeStyleGestureController(makeGestureMatcher: Self.makeGestureMatcher)

    controller.configureDefaultButtonRecognizer()

    XCTAssertEqual(controller.recognizer?.snapshot.status.lifecycle, .idle)
  }

  func testReadmeStylePrimaryButtonConfigurationTypeChecks() {
    let eventTap = GestureEventTap(capturedButtons: [.primary])
    let configuration = GestureRecognizerConfiguration<AppCommand>(
      makeMatcher: { _ in Self.makeGestureMatcher() },
      onReplayRequested: { request in eventTap.replay(request) },
      onMatch: { _ in },
      recognitionButton: .primary
    )

    let recognizer = GestureRecognizer(
      eventSource: eventTap,
      configuration: configuration
    )

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
  }

  private static func makeGestureMatcher() -> GesturePatternMatcher<AppCommand> {
    var matcher = GesturePatternMatcher<AppCommand>()
    matcher.register(pattern: [.down, .right], match: .showInspector)
    matcher.register(pattern: [.up, .left], match: .focusSearch)
    return matcher
  }
}

private extension GestureEventTapInputDispatch {
  func pendingSyntheticEventSignatureCount(
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Int {
    syntheticEventSuppression.pendingSignatureCount(file: file, line: line)
  }
}

private extension SyntheticEventSuppression {
  func pendingSignatureCount(file: StaticString = #filePath, line: UInt = #line) -> Int {
    guard
      let signatures = Mirror(reflecting: self).children.first(where: {
        $0.label == "pendingSignatures"
      })?.value as? [SyntheticEventSignature]
    else {
      XCTFail(
        "Expected SyntheticEventSuppression to store pendingSignatures",
        file: file,
        line: line
      )
      return -1
    }
    return signatures.count
  }
}

private enum AppCommand: Sendable {
  case showInspector
  case focusSearch
}

@MainActor
private final class ReadmeStyleGestureController {
  var recognizer: GestureRecognizer<AppCommand>?

  private let makeGestureMatcher: @MainActor () -> GesturePatternMatcher<AppCommand>

  init(makeGestureMatcher: @escaping @MainActor () -> GesturePatternMatcher<AppCommand>) {
    self.makeGestureMatcher = makeGestureMatcher
  }

  func configureDefaultButtonRecognizer() {
    let eventTap = GestureEventTap()
    let configuration = GestureRecognizerConfiguration<AppCommand>(
      makeMatcher: { [makeGestureMatcher] _ in makeGestureMatcher() },
      onReplayRequested: { request in eventTap.replay(request) },
      onMatch: { _ in },
      areModifiersSatisfied: { modifiers, _ in
        modifiers.contains(.command)
      }
    )

    recognizer = GestureRecognizer(
      eventSource: eventTap,
      configuration: configuration
    )
  }
}
