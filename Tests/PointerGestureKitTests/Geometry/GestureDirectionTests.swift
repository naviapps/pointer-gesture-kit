import PointerGestureKit
import XCTest

final class GestureDirectionTests: XCTestCase {
  func testHashableContractSupportsCollections() {
    XCTAssertEqual(
      Set<GestureDirection>([.up, .up, .down, .left, .right]),
      [.up, .down, .left, .right]
    )
  }

  func testSendableContractAcceptsDirectionValues() {
    assertSendable(GestureDirection.up)
  }
}
