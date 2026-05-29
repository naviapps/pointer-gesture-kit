import enum CoreGraphics.CGEventType
import XCTest

@testable import PointerGestureKitCoreGraphics

final class SyntheticEventSuppressionTests: XCTestCase {
  func testConsumeRemovesMatchingPendingReplayedEventsInOrder() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseDown, replayedRightMouseUp])

    XCTAssertTrue(suppression.consume(replayedRightMouseDown))
    XCTAssertTrue(suppression.consume(replayedRightMouseUp))
    XCTAssertFalse(suppression.consume(replayedRightMouseUp))
  }

  func testSuppressAppendsPendingReplayedEvents() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseDown])
    suppression.suppress([replayedRightMouseUp])

    XCTAssertTrue(suppression.consume(replayedRightMouseDown))
    XCTAssertTrue(suppression.consume(replayedRightMouseUp))
  }

  func testConsumeDropsMissedEarlierSyntheticEventsWhenLaterEventArrives() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseDown, replayedRightMouseUp])

    XCTAssertTrue(suppression.consume(replayedRightMouseUp))
    XCTAssertFalse(suppression.consume(replayedRightMouseDown))
    XCTAssertFalse(suppression.consume(replayedRightMouseUp))
  }

  func testConsumeLeavesPendingEventsWhenEventIsNotPending() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseUp])

    XCTAssertFalse(suppression.consume(replayedLeftMouseUp))
    XCTAssertTrue(suppression.consume(replayedRightMouseUp))
  }

  func testRemoveAllClearsPendingReplayedEvents() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseDown, replayedRightMouseUp])
    suppression.removeAll()

    XCTAssertFalse(suppression.consume(replayedRightMouseDown))
    XCTAssertFalse(suppression.consume(replayedRightMouseUp))
  }

  func testConsumeRequiresSyntheticReplayMarker() {
    var suppression = SyntheticEventSuppression()

    suppression.suppress([replayedRightMouseUp])

    XCTAssertFalse(suppression.consume(observedRightMouseUp))
    XCTAssertTrue(suppression.consume(replayedRightMouseUp))
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
