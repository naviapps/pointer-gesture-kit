import PointerGestureKit
import XCTest

final class GestureModifierFlagsTests: XCTestCase {
  func testOptionSetMembershipCombinesKnownFlags() {
    let flags: GestureModifierFlags = [.command, .shift]

    XCTAssertTrue(flags.contains(.command))
    XCTAssertTrue(flags.contains(.shift))
    XCTAssertFalse(flags.contains(.option))
    XCTAssertFalse(flags.contains(.control))
    XCTAssertEqual(Set<GestureModifierFlags>([flags, flags, [.option]]), [flags, [.option]])
  }

  func testRawValuesUseKnownBitPositions() {
    XCTAssertEqual(GestureModifierFlags.command.rawValue, 1 << 0)
    XCTAssertEqual(GestureModifierFlags.option.rawValue, 1 << 1)
    XCTAssertEqual(GestureModifierFlags.control.rawValue, 1 << 2)
    XCTAssertEqual(GestureModifierFlags.shift.rawValue, 1 << 3)
  }

  func testInitializerPreservesUnknownRawBits() {
    let flags = GestureModifierFlags(rawValue: (1 << 20) | GestureModifierFlags.command.rawValue)

    XCTAssertEqual(flags.rawValue, (1 << 20) | GestureModifierFlags.command.rawValue)
    XCTAssertTrue(flags.contains(.command))
  }

  func testInitializerPreservesNegativeRawValue() {
    let flags = GestureModifierFlags(rawValue: -1)

    XCTAssertEqual(flags.rawValue, -1)
  }

  func testSendableContractAcceptsModifierFlags() {
    assertSendable(GestureModifierFlags.command)
    assertSendable(GestureModifierFlags([.command, .shift]))
  }

}
