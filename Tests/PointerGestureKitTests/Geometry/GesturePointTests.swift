import PointerGestureKit
import XCTest

final class GesturePointTests: XCTestCase {
  func testInitializerPreservesFiniteCoordinates() {
    let point = GesturePoint(x: 12.5, y: -8.25)

    XCTAssertEqual(point.x, 12.5)
    XCTAssertEqual(point.y, -8.25)
  }

  func testZeroIsOrigin() {
    XCTAssertEqual(GesturePoint.zero, GesturePoint(x: 0, y: 0))
  }

  func testFiniteStateIsExplicit() {
    XCTAssertTrue(GesturePoint(x: 1, y: 2).isFinite)
    XCTAssertFalse(GesturePoint(x: .nan, y: 2).isFinite)
    XCTAssertFalse(GesturePoint(x: 1, y: .infinity).isFinite)
  }

  func testSendableContractAcceptsPointValues() {
    assertSendable(GesturePoint(x: 1, y: 2))
  }

}
