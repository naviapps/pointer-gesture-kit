import PointerGestureKit
import XCTest

final class GestureEventDispositionTests: XCTestCase {
  func testCasesDefineOriginalEventHandling() {
    XCTAssertTrue(GestureEventDisposition.consume.consumesOriginalEvent)
    XCTAssertFalse(GestureEventDisposition.passThrough.consumesOriginalEvent)
  }

  func testSendableContractAcceptsDispositionValues() {
    assertSendable(GestureEventDisposition.consume)
    assertSendable(GestureEventDisposition.passThrough)
  }

  func testEquatableContractDistinguishesActions() {
    XCTAssertNotEqual(GestureEventDisposition.consume, .passThrough)
  }
}
