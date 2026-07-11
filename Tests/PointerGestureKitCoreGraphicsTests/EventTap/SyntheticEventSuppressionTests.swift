import enum CoreGraphics.CGEventType
import XCTest

@testable import PointerGestureKitCoreGraphics

final class SyntheticEventSuppressionTests: XCTestCase {
  func testConsumesPendingReplayedEventsInOrder() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseDown])
    suppression.suppress([replayedRightMouseUp])

    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseDown))
    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))
    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))
    XCTAssertFalse(suppression.consumeThrough(observedRightMouseUp))
  }

  func testDropsMissedEarlierReplayedEventsWhenLaterEventArrives() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseDown, replayedRightMouseUp])

    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))
    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseDown))
    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))
  }

  func testKeepsPendingEventsUntilResetOrMatchingReplayArrives() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseUp])

    XCTAssertTrue(suppression.consumeThrough(replayedLeftMouseUp))
    XCTAssertFalse(suppression.consumeThrough(observedRightMouseUp))
    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))

    suppression.suppress([replayedRightMouseUp])
    suppression.removeAll()

    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))
  }

  func testIgnoresReplayedEventsEvenWhenCapacityDropsPendingSignature() {
    var suppression = SyntheticEventSuppression(maximumPendingSignatureCount: 3)
    let signatures = [
      SyntheticEventSignature.replayed(type: .rightMouseDown, button: .secondary),
      SyntheticEventSignature.replayed(type: .rightMouseDragged, button: .secondary),
      SyntheticEventSignature.replayed(type: .rightMouseUp, button: .secondary),
      SyntheticEventSignature.replayed(type: .leftMouseDown, button: .primary),
      SyntheticEventSignature.replayed(type: .leftMouseUp, button: .primary),
    ]

    suppression.suppress(signatures)

    XCTAssertTrue(suppression.consumeThrough(signatures[0]))
    XCTAssertTrue(suppression.consumeThrough(signatures[1]))
    XCTAssertTrue(suppression.consumeThrough(signatures[2]))
    XCTAssertTrue(suppression.consumeThrough(signatures[3]))
    XCTAssertTrue(suppression.consumeThrough(signatures[4]))
  }

  func testIgnoresUnexpectedReplayedEventsWithoutPendingSignature() {
    var suppression = SyntheticEventSuppression()

    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseDown))
    XCTAssertTrue(suppression.consumeThrough(replayedRightMouseUp))
    XCTAssertFalse(suppression.consumeThrough(observedRightMouseUp))
  }
}

private let replayedRightMouseDown = SyntheticEventSignature.replayed(
  type: .rightMouseDown,
  button: .secondary
)
private let replayedRightMouseUp = SyntheticEventSignature.replayed(
  type: .rightMouseUp,
  button: .secondary
)
private let replayedLeftMouseUp = SyntheticEventSignature.replayed(
  type: .leftMouseUp,
  button: .primary
)
private let observedRightMouseUp = SyntheticEventSignature.observed(
  type: .rightMouseUp,
  button: .secondary,
  eventSourceUserData: 0
)
