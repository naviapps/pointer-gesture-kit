import PointerGestureKit
import XCTest

final class GestureModifierFlagsTests: XCTestCase {
  func testOptionSetMembershipCombinesKnownFlags() {
    let flags: GestureModifierFlags = [.command, .shift]

    XCTAssertTrue(flags.contains(.command))
    XCTAssertTrue(flags.contains(.shift))
    XCTAssertFalse(flags.contains(.option))
    XCTAssertFalse(flags.contains(.control))
  }

  func testRawValuesUseStableKnownBitPositions() {
    XCTAssertEqual(GestureModifierFlags.command.rawValue, 1 << 0)
    XCTAssertEqual(GestureModifierFlags.option.rawValue, 1 << 1)
    XCTAssertEqual(GestureModifierFlags.control.rawValue, 1 << 2)
    XCTAssertEqual(GestureModifierFlags.shift.rawValue, 1 << 3)
  }

  func testInitializerDiscardsUnknownRawBits() {
    let flags = GestureModifierFlags(rawValue: (1 << 20) | GestureModifierFlags.command.rawValue)

    XCTAssertEqual(flags, [.command])
  }

  func testInitializerMasksNegativeRawValueToKnownBits() {
    let flags = GestureModifierFlags(rawValue: -1)

    XCTAssertEqual(flags, [.command, .option, .control, .shift])
  }

  func testHashableContractSupportsCollections() {
    XCTAssertEqual(
      Set<GestureModifierFlags>([[.command], [.command], [.shift]]),
      [
        [.command], [.shift],
      ])
  }

  func testSendableContractAcceptsModifierFlags() {
    assertSendable(GestureModifierFlags.command)
    assertSendable(GestureModifierFlags([.command, .shift]))
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureModifierFlags.self is any Codable.Type)
    XCTAssertFalse(GestureModifierFlags.self is any CaseIterable.Type)
    XCTAssertFalse(GestureModifierFlags.self is any Error.Type)
  }
}
