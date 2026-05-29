import PointerGestureKit
import XCTest

final class GestureEventDispositionTests: XCTestCase {
  func testCasesDefineOriginalEventHandling() {
    XCTAssertTrue(originalEventIsSuppressed(by: .consume))
    XCTAssertFalse(originalEventIsSuppressed(by: .passThrough))
  }

  func testHashableContractSupportsCollections() {
    XCTAssertEqual(
      Set<GestureEventDisposition>([.consume, .consume, .passThrough]),
      [.consume, .passThrough]
    )
  }

  func testSendableContractAcceptsDispositionValues() {
    assertSendable(GestureEventDisposition.consume)
    assertSendable(GestureEventDisposition.passThrough)
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureEventDisposition.self is any Codable.Type)
    XCTAssertFalse(GestureEventDisposition.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureEventDisposition.self is any CaseIterable.Type)
    XCTAssertFalse(GestureEventDisposition.self is any Error.Type)
  }

  private func originalEventIsSuppressed(by disposition: GestureEventDisposition) -> Bool {
    switch disposition {
    case .consume:
      true
    case .passThrough:
      false
    }
  }
}
