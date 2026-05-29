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
        case .drag:
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
      tuning: GestureRecognizerTuning(
        minimumGestureStartAxisDistance: 1,
        minimumDirectionChangeAxisDistance: 2,
        maximumGestureSessionDuration: 3,
        maximumRawPointCount: 25,
        eventSourceStartRetryDelays: [0]
      )
    )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero, modifiers: [.command]))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: GesturePoint(x: 10, y: 0)))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: GesturePoint(x: 20, y: 0)))

    XCTAssertNil(clickPoint)
    XCTAssertEqual(releasePoint, GesturePoint(x: 20, y: 0))
    XCTAssertEqual(matcherContext, context)
    XCTAssertEqual(modifierPolicyContext, context)
    XCTAssertEqual(matchedID, id)
  }

  func testRecognitionButtonSelectsWhichPointerButtonCanStartGestures() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        recognitionButton: .primary,
        tuning: .testing(minimumGestureStartAxisDistance: 0)
      )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .passThrough
    )
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.primary), location: .zero)),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonUp(.primary), location: .zero)),
      .consume
    )

    XCTAssertEqual(replayRequests, [.click(button: .primary, at: .zero)])
  }

  func testRecognitionButtonSupportsMiddlePointerButton() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        recognitionButton: .middle,
        tuning: .testing(minimumGestureStartAxisDistance: 0)
      )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .passThrough
    )
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.middle), location: .zero)),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonUp(.middle), location: .zero)),
      .consume
    )

    XCTAssertEqual(replayRequests, [.click(button: .middle, at: .zero)])
  }

  func testRecognitionButtonSupportsAdditionalPointerButton() throws {
    let additionalButton = try XCTUnwrap(PointerButton(additionalButtonNumber: 4))
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        recognitionButton: additionalButton,
        tuning: .testing(minimumGestureStartAxisDistance: 0)
      )
    let recognizer = GestureRecognizer(eventSource: eventSource, configuration: configuration)

    recognizer.start()
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .passThrough
    )
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(additionalButton), location: .zero)),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonUp(additionalButton), location: .zero)),
      .consume
    )

    XCTAssertEqual(replayRequests, [.click(button: additionalButton, at: .zero)])
  }

  func testSendableContractAcceptsConfiguration() {
    let configuration = GestureRecognizerConfiguration<UUID>(
      makeMatcher: { _ in GesturePatternMatcher<UUID>() },
      onReplayRequested: { _ in },
      onMatch: { _ in }
    )

    assertSendable(configuration)
  }

  func testDoesNotExposeValueSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureRecognizerConfiguration<UUID>.self is any Equatable.Type)
    XCTAssertFalse(GestureRecognizerConfiguration<UUID>.self is any Hashable.Type)
    XCTAssertFalse(GestureRecognizerConfiguration<UUID>.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerConfiguration<UUID>.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerConfiguration<UUID>.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerConfiguration<UUID>.self is any Error.Type)
  }
}
