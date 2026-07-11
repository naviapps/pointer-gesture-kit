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

  func testTapDisabledRecoveryDispatchesCancelImmediatelyOnMainActor() {
    let eventTap = GestureEventTap()
    var handledKinds: [GestureInputEvent.Kind] = []
    _ = eventTap.start { input in
      handledKinds.append(input.kind)
      return .consume
    }

    eventTap.recoverFromTapDisabled(
      input: GestureInputEvent(
        kind: .cancel,
        location: .zero,
        modifiers: []
      ),
      sourceSignature: .tapDisabledTimeout
    )

    XCTAssertEqual(handledKinds, [.cancel])
  }

  func testTapDisabledRecoveryClearsPendingSyntheticSuppressionBeforeDispatchingCancel() {
    let eventTap = GestureEventTap()
    var pendingCountsSeenByHandler: [Int] = []
    _ = eventTap.start { input in
      XCTAssertEqual(input.kind, .cancel)
      pendingCountsSeenByHandler.append(eventTap.pendingSyntheticEventSignatureCount())
      eventTap.suppressNextSyntheticEventSignatures([
        .replayed(type: .leftMouseUp, button: .primary)
      ])
      return .consume
    }
    eventTap.suppressNextSyntheticEventSignatures([
      .replayed(type: .rightMouseUp, button: .secondary)
    ])

    eventTap.recoverFromTapDisabled(
      input: GestureInputEvent(
        kind: .cancel,
        location: .zero,
        modifiers: []
      ),
      sourceSignature: .tapDisabledTimeout
    )

    XCTAssertEqual(pendingCountsSeenByHandler, [0])
    XCTAssertEqual(eventTap.pendingSyntheticEventSignatureCount(), 1)
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

private extension GestureEventTap {
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
