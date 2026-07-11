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
    assertDisposition(send(.buttonDown(.secondary), at: .zero), .consume)
    assertDisposition(send(.buttonMoved(.secondary), at: .init(x: 0, y: 40)), .consume)
    assertDisposition(send(.buttonMoved(.secondary), at: .init(x: 40, y: 40)), .consume)
    assertDisposition(send(.buttonUp(.secondary), at: .init(x: 40, y: 40)), .consume)

    XCTAssertEqual(matchedCommands, [.showInspector])
    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 40))])
  }

  func testRecognizerIsReferenceOwnedAndSendableFromPublicUse() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let eventSourceContract: any GestureEventSource = eventSource
    let recognizer = GestureRecognizer(
      eventSource: eventSource,
      configuration: GestureRecognizerConfiguration<AppCommand>(
        makeMatcher: { _ in Self.makeGestureMatcher() },
        onReplayRequested: { _ in },
        onMatch: { _ in }
      )
    )

    XCTAssertTrue(eventSourceContract === eventSource)
    assertSendable(recognizer)
  }

  func testRecognizerPassesThroughNonFiniteInputWithoutStartingState() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = GestureRecognizer(
      eventSource: eventSource,
      configuration: GestureRecognizerConfiguration<AppCommand>(
        makeMatcher: { _ in Self.makeGestureMatcher() },
        onReplayRequested: { _ in },
        onMatch: { _ in }
      )
    )

    recognizer.start()
    let disposition = eventSource.send(
      makeGestureInputEvent(
        kind: .buttonDown(.secondary),
        location: GesturePoint(x: .nan, y: 10)
      )
    )

    assertDisposition(disposition, .passThrough)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
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
