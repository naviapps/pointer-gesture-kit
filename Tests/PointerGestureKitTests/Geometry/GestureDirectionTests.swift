import PointerGestureKit
import XCTest

final class GestureDirectionTests: XCTestCase {
  func testAllCasesAreCardinalInDeclarationOrder() {
    XCTAssertEqual(GestureDirection.allCases, [.up, .down, .left, .right])
  }

  func testHashableContractSupportsCollections() {
    XCTAssertEqual(
      Set<GestureDirection>([.up, .up, .down, .left, .right]),
      [.up, .down, .left, .right]
    )
  }

  func testSendableContractAcceptsDirectionValues() {
    assertSendable(GestureDirection.up)
  }

  func testDoesNotExposeSerializationOrErrorContracts() {
    XCTAssertFalse(GestureDirection.self is any Codable.Type)
    XCTAssertFalse(GestureDirection.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureDirection.self is any Error.Type)
  }
}
