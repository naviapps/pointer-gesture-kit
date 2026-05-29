import PointerGestureKit
import XCTest

@MainActor
final class GestureRecognizerBasicUsageTests: XCTestCase {
  func testBasicUsageRecognizesMatchedCommand() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var matchedCommands: [AppCommand] = []
    var replayRequests: [GestureReplayRequest] = []

    let configuration = GestureRecognizerConfiguration<AppCommand>(
      makeMatcher: { _ in Self.makeGestureMatcher() },
      onReplayRequested: { request in
        replayRequests.append(request)
      },
      onMatch: { command in
        matchedCommands.append(command)
      },
      areModifiersSatisfied: { modifiers, _ in
        modifiers.contains(.command)
      }
    )

    let recognizer = GestureRecognizer(
      eventSource: eventSource,
      configuration: configuration
    )

    func send(_ kind: GestureInputEvent.Kind, at point: GesturePoint) -> GestureEventDisposition {
      eventSource.send(makeGestureInputEvent(kind: kind, location: point, modifiers: [.command]))
    }

    recognizer.start()
    XCTAssertEqual(send(.buttonDown(.secondary), at: .zero), .consume)
    XCTAssertEqual(send(.buttonDragged(.secondary), at: .init(x: 0, y: 40)), .consume)
    XCTAssertEqual(send(.buttonDragged(.secondary), at: .init(x: 40, y: 40)), .consume)
    XCTAssertEqual(send(.buttonUp(.secondary), at: .init(x: 40, y: 40)), .consume)

    XCTAssertEqual(matchedCommands, [.showInspector])
    XCTAssertEqual(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 40))])
  }

  func testRecognizerPublicContractIsReferenceOwnedAndSendable() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = GestureRecognizer(
      eventSource: eventSource,
      configuration: GestureRecognizerConfiguration<AppCommand>(
        makeMatcher: { _ in Self.makeGestureMatcher() },
        onReplayRequested: { _ in },
        onMatch: { _ in }
      )
    )

    assertSendable(recognizer)
    XCTAssertFalse(GestureRecognizer<AppCommand>.self is any Equatable.Type)
    XCTAssertFalse(GestureRecognizer<AppCommand>.self is any Hashable.Type)
    XCTAssertFalse(GestureRecognizer<AppCommand>.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizer<AppCommand>.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizer<AppCommand>.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizer<AppCommand>.self is any Error.Type)
  }

  private static func makeGestureMatcher() -> GesturePatternMatcher<AppCommand> {
    var matcher = GesturePatternMatcher<AppCommand>()
    matcher.register(pattern: [.down, .right], match: .showInspector)
    matcher.register(pattern: [.up, .left], match: .focusSearch)
    return matcher
  }
}

private enum AppCommand: Equatable, Sendable {
  case showInspector
  case focusSearch
}
