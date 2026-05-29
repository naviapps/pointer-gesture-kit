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

  func testInitializerReplacesNonFiniteCoordinatesWithZero() {
    XCTAssertEqual(GesturePoint(x: .nan, y: .infinity), .zero)
    XCTAssertEqual(GesturePoint(x: -.infinity, y: 12.5), GesturePoint(x: 0, y: 12.5))
  }

  func testHashableContractSupportsCollections() {
    XCTAssertEqual(
      Set([GesturePoint(x: 1, y: 2), GesturePoint(x: 1, y: 2), GesturePoint(x: 2, y: 1)]),
      [GesturePoint(x: 1, y: 2), GesturePoint(x: 2, y: 1)]
    )
  }

  func testSendableContractAcceptsPointValues() {
    assertSendable(GesturePoint(x: 1, y: 2))
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GesturePoint.self is any Codable.Type)
    XCTAssertFalse(GesturePoint.self is any RawRepresentable.Type)
    XCTAssertFalse(GesturePoint.self is any CaseIterable.Type)
    XCTAssertFalse(GesturePoint.self is any Error.Type)
  }
}
