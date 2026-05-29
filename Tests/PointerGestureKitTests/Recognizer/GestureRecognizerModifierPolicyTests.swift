import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerModifierPolicyTests: XCTestCase {
  func testButtonDownIsConsumedWhenModifierPolicyIsSatisfied() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        areModifiersSatisfied: { modifiers, _ in
          modifiers.contains(.command)
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)

    let down = makeGestureInputEvent(
      kind: .buttonDown(.secondary), location: .init(x: 10, y: 10), modifiers: [.command])
    let result = eventSource.send(down)
    XCTAssertEqual(result, .consume)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
  }

  func testButtonDownPassesThroughAndSetsFailureWhenModifierPolicyIsNotSatisfied() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        areModifiersSatisfied: { modifiers, _ in
          modifiers.contains(.command)
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)

    let down = makeGestureInputEvent(
      kind: .buttonDown(.secondary), location: .init(x: 10, y: 10), modifiers: [])
    let result = eventSource.send(down)
    XCTAssertEqual(result, .passThrough)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .modifiersNotSatisfied)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  func testRepeatedButtonDownDuringActiveSessionDoesNotRecheckModifiers() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var modifierPolicyCallCount = 0
    var releaseRequests: [GesturePoint] = []

    let matchedID = UUID()
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: matchedID)
          return matcher
        },
        onReplayRequested: { request in
          if case let .release(_, point) = request {
            releaseRequests.append(point)
          }
        },
        areModifiersSatisfied: { modifiers, _ in
          modifierPolicyCallCount += 1
          return modifiers.contains(.command)
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(
          kind: .buttonDown(.secondary),
          location: .init(x: 10, y: 10),
          modifiers: [.command]
        )),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(
          kind: .buttonDragged(.secondary),
          location: .init(x: 100, y: 10),
          modifiers: [.command]
        )),
      .consume
    )
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 120, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(modifierPolicyCallCount, 1)
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(
          kind: .buttonUp(.secondary),
          location: .init(x: 140, y: 10),
          modifiers: [.command]
        )),
      .consume
    )
    XCTAssertEqual(releaseRequests, [.init(x: 140, y: 10)])
  }

  func testRecordingModeGestureStartClearsStaleModifierFailure() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        areModifiersSatisfied: { modifiers, _ in
          modifiers.contains(.command)
        }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .passThrough
    )
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .modifiersNotSatisfied)

    recognizer.isRecordingModeEnabled = true
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 20, y: 20))
      ),
      .consume
    )

    XCTAssertNil(recognizer.snapshot.status.lastFailure)
  }
}
