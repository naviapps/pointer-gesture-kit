import PointerGestureKit
import XCTest

final class PointerButtonTests: XCTestCase {
  func testCasesRepresentPlatformNeutralPointerButtons() throws {
    let additionalButton = try makeAdditionalButton()

    XCTAssertEqual(Set<PointerButton>([.primary, .secondary, .middle, additionalButton]).count, 4)
  }

  func testAdditionalButtonInitializerRejectsReservedButtonNumbers() {
    XCTAssertNil(PointerButton(additionalButtonNumber: 0))
    XCTAssertNil(PointerButton(additionalButtonNumber: 1))
    XCTAssertNil(PointerButton(additionalButtonNumber: 2))
  }

  func testAdditionalButtonInitializerStoresAdditionalButtonNumber() {
    XCTAssertEqual(PointerButton(additionalButtonNumber: 3)?.additionalButtonNumber, 3)
    XCTAssertEqual(PointerButton(additionalButtonNumber: 4)?.additionalButtonNumber, 4)
    XCTAssertEqual(
      PointerButton(additionalButtonNumber: UInt32.max)?.additionalButtonNumber,
      UInt32.max
    )
    XCTAssertNil(PointerButton.primary.additionalButtonNumber)
    XCTAssertNil(PointerButton.secondary.additionalButtonNumber)
    XCTAssertNil(PointerButton.middle.additionalButtonNumber)
  }

  func testEqualityUsesAdditionalButtonNumber() throws {
    let button = try XCTUnwrap(PointerButton(additionalButtonNumber: 4))
    let same = try XCTUnwrap(PointerButton(additionalButtonNumber: 4))
    let different = try XCTUnwrap(PointerButton(additionalButtonNumber: 5))

    XCTAssertEqual(button, same)
    XCTAssertNotEqual(button, different)
  }

  func testHashableContractSupportsCollections() throws {
    let additionalButton = try makeAdditionalButton()

    XCTAssertEqual(
      Set<PointerButton>([.primary, .primary, .secondary, additionalButton, additionalButton]),
      [.primary, .secondary, additionalButton]
    )
  }

  func testSendableContractAcceptsPointerButtonValues() throws {
    assertSendable(PointerButton.primary)
    assertSendable(try makeAdditionalButton())
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(PointerButton.self is any Codable.Type)
    XCTAssertFalse(PointerButton.self is any RawRepresentable.Type)
    XCTAssertFalse(PointerButton.self is any CaseIterable.Type)
    XCTAssertFalse(PointerButton.self is any Error.Type)
  }
}

private func makeAdditionalButton() throws -> PointerButton {
  try XCTUnwrap(PointerButton(additionalButtonNumber: 4))
}
