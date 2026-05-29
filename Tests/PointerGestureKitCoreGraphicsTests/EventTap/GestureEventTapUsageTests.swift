import PointerGestureKit
import PointerGestureKitCoreGraphics
import XCTest

@MainActor
final class GestureEventTapUsageTests: XCTestCase {
  func testReadmeStyleDefaultButtonConfigurationTypeChecks() {
    let eventTap = GestureEventTap()
    let configuration = GestureRecognizerConfiguration<AppCommand>(
      makeMatcher: { _ in Self.makeGestureMatcher() },
      onReplayRequested: eventTap.replay,
      onMatch: { _ in },
      areModifiersSatisfied: { modifiers, _ in
        modifiers.contains(.command)
      }
    )

    let recognizer = GestureRecognizer(
      eventSource: eventTap,
      configuration: configuration
    )

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
  }

  func testReadmeStylePrimaryButtonConfigurationTypeChecks() {
    let eventTap = GestureEventTap(capturedButtons: [.primary])
    let configuration = GestureRecognizerConfiguration<AppCommand>(
      makeMatcher: { _ in Self.makeGestureMatcher() },
      onReplayRequested: eventTap.replay,
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

private enum AppCommand: Sendable {
  case showInspector
  case focusSearch
}
