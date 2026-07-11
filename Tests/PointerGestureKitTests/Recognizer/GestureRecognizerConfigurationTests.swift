import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerConfigurationTests: XCTestCase {
  func testMinimalConfigurationAllowsRecognizerToStart() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration = GestureRecognizerConfiguration<UUID>(
      makeMatcher: { _ in GesturePatternMatcher<UUID>() },
      onReplayRequested: { _ in },
      onMatch: { _ in }
    )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
  }

  func testDefaultPoliciesAllowSecondaryGestureWithoutContextOrModifiers() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var matchedID: UUID?
    var replayRequests: [GestureReplayRequest] = []
    let id = UUID()
    let configuration = GestureRecognizerConfiguration<UUID>(
      makeMatcher: { context in
        XCTAssertNil(context)
        var matcher = GesturePatternMatcher<UUID>()
        matcher.register(pattern: [.right], match: id)
        return matcher
      },
      onReplayRequested: { replayRequests.append($0) },
      onMatch: { matchedID = $0 }
    )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()
    assertDisposition(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 0))),
      .consume
    )

    XCTAssertEqual(matchedID, id)
    assertReplayRequests(replayRequests, [.release(button: .secondary, at: .init(x: 40, y: 0))])
  }

  func testConstructedConfigurationDrivesRecognition() throws {
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: "custom"))
    var clickPoint: GesturePoint?
    var releasePoint: GesturePoint?
    var matchedID: UUID?
    var matcherContext: GestureRecognitionContext?
    var modifierPolicyContext: GestureRecognitionContext?
    let id = UUID()
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration = GestureRecognizerConfiguration<UUID>(
      makeMatcher: { context in
        matcherContext = context
        var matcher = GesturePatternMatcher<UUID>()
        matcher.register(pattern: [.right], match: id)
        return matcher
      },
      onReplayRequested: { request in
        switch request {
        case let .click(_, point):
          clickPoint = point
        case .drag, .dragStart:
          XCTFail("Matched gestures should not replay the consumed sequence.")
        case let .release(_, point):
          releasePoint = point
        }
      },
      onMatch: { matchedID = $0 },
      recognitionContext: { _ in context },
      isRecognitionEnabled: { $0 == context },
      areModifiersSatisfied: { modifiers, receivedContext in
        modifierPolicyContext = receivedContext
        return receivedContext == context && modifiers.contains(.command)
      },
      tuning: .testing(
        minimumGestureStartAxisDistance: 0,
        minimumDirectionChangeAxisDistance: 0
      )
    )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero, modifiers: [.command]))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: GesturePoint(x: 10, y: 0)))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: GesturePoint(x: 20, y: 0)))

    XCTAssertNil(clickPoint)
    XCTAssertEqual(releasePoint, GesturePoint(x: 20, y: 0))
    XCTAssertEqual(matcherContext, context)
    XCTAssertEqual(modifierPolicyContext, context)
    XCTAssertEqual(matchedID, id)
  }

  func testRecognitionButtonSelectsWhichPointerButtonCanStartGestures() throws {
    let auxiliaryButton = try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))

    assertRecognitionButtonStartsGesture(.primary)
    assertRecognitionButtonStartsGesture(.middle)
    assertRecognitionButtonStartsGesture(auxiliaryButton)
  }

  func testSendableContractAcceptsConfiguration() {
    let configuration = GestureRecognizerConfiguration<UUID>(
      makeMatcher: { _ in GesturePatternMatcher<UUID>() },
      onReplayRequested: { _ in },
      onMatch: { _ in }
    )

    assertSendable(configuration)
  }

}

@MainActor
private func assertRecognitionButtonStartsGesture(
  _ button: PointerButton,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  let eventSource = GestureEventSourceDouble(startResult: true)
  var replayRequests: [GestureReplayRequest] = []
  let configuration: GestureRecognizerConfiguration<UUID> =
    makeGestureRecognizerTestConfiguration(
      onReplayRequested: { replayRequests.append($0) },
      recognitionButton: button,
      tuning: .testing(minimumGestureStartAxisDistance: 0)
    )
  let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

  recognizer.start()
  assertDisposition(
    eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
    .passThrough,
    file: file,
    line: line
  )
  assertDisposition(
    eventSource.send(makeGestureInputEvent(kind: .buttonDown(button), location: .zero)),
    .consume,
    file: file,
    line: line
  )
  assertDisposition(
    eventSource.send(makeGestureInputEvent(kind: .buttonUp(button), location: .zero)),
    .consume,
    file: file,
    line: line
  )

  assertReplayRequests(replayRequests, [.click(button: button, at: .zero)], file: file, line: line)
}
