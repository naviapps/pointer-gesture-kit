import PointerGestureKit
import XCTest

final class PointerButtonTests: XCTestCase {
  func testCasesRepresentPlatformNeutralPointerButtons() throws {
    let auxiliaryButton = try makeAuxiliaryButton()

    XCTAssertEqual(Set<PointerButton>([.primary, .secondary, .middle, auxiliaryButton]).count, 4)
  }

  func testAuxiliaryButtonInitializerRejectsReservedButtonIdentifiers() {
    XCTAssertNil(PointerButton(auxiliaryButtonID: 0))
    XCTAssertNil(PointerButton(auxiliaryButtonID: 1))
    XCTAssertNil(PointerButton(auxiliaryButtonID: 2))
  }

  func testAuxiliaryButtonInitializerStoresAuxiliaryButtonIdentifier() {
    XCTAssertEqual(PointerButton(auxiliaryButtonID: 3)?.auxiliaryButtonID, 3)
    XCTAssertEqual(PointerButton(auxiliaryButtonID: 4)?.auxiliaryButtonID, 4)
    XCTAssertEqual(
      PointerButton(auxiliaryButtonID: UInt32.max)?.auxiliaryButtonID,
      UInt32.max
    )
    XCTAssertNil(PointerButton.primary.auxiliaryButtonID)
    XCTAssertNil(PointerButton.secondary.auxiliaryButtonID)
    XCTAssertNil(PointerButton.middle.auxiliaryButtonID)
  }

  func testEqualityUsesAuxiliaryButtonIdentifier() throws {
    let button = try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))
    let same = try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))
    let different = try XCTUnwrap(PointerButton(auxiliaryButtonID: 5))

    XCTAssertEqual(button, same)
    XCTAssertNotEqual(button, different)
    XCTAssertEqual(
      Set<PointerButton>([button, same, different]),
      [button, different]
    )
  }

  func testSendableContractAcceptsPointerButtonValues() throws {
    assertSendable(PointerButton.primary)
    assertSendable(try makeAuxiliaryButton())
  }

}

private func makeAuxiliaryButton() throws -> PointerButton {
  try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))
}
