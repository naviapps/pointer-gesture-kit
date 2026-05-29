import enum CoreGraphics.CGEventType
import enum CoreGraphics.CGMouseButton
import PointerGestureKit
import XCTest

@testable import PointerGestureKitCoreGraphics

final class PointerButtonConversionTests: XCTestCase {
  func testPointerButtonMapsCoreGraphicsButtonNumbers() {
    XCTAssertEqual(PointerButton(cgButtonNumber: 0), .primary)
    XCTAssertEqual(PointerButton(cgButtonNumber: 1), .secondary)
    XCTAssertEqual(PointerButton(cgButtonNumber: 2), .middle)
    XCTAssertEqual(
      PointerButton(cgButtonNumber: 3),
      PointerButton(additionalButtonNumber: 3)
    )
    XCTAssertEqual(
      PointerButton(cgButtonNumber: Int64(UInt32.max)),
      PointerButton(additionalButtonNumber: UInt32.max)
    )
  }

  func testPointerButtonRejectsInvalidCoreGraphicsButtonNumbers() {
    XCTAssertNil(PointerButton(cgButtonNumber: -1))
    XCTAssertNil(PointerButton(cgButtonNumber: Int64(UInt32.max) + 1))
  }

  func testCoreGraphicsMouseButtonMapsPointerButtons() throws {
    let additionalButton = try XCTUnwrap(PointerButton(additionalButtonNumber: 3))

    XCTAssertEqual(PointerButton.primary.cgMouseButton, .left)
    XCTAssertEqual(PointerButton.secondary.cgMouseButton, .right)
    XCTAssertEqual(PointerButton.middle.cgMouseButton, .center)
    XCTAssertEqual(additionalButton.cgMouseButton, CGMouseButton(rawValue: 3))
  }

  func testPointerButtonClassifiesCoreGraphicsEventFamilies() throws {
    let additionalButton = try XCTUnwrap(PointerButton(additionalButtonNumber: 4))

    XCTAssertFalse(PointerButton.primary.usesOtherMouseEventTypes)
    XCTAssertFalse(PointerButton.secondary.usesOtherMouseEventTypes)
    XCTAssertTrue(PointerButton.middle.usesOtherMouseEventTypes)
    XCTAssertTrue(additionalButton.usesOtherMouseEventTypes)
  }

  func testPointerButtonsExposeCoreGraphicsEventFamilies() {
    XCTAssertEqual(
      PointerButton.primary.cgEventTypes,
      PointerButtonCGEventTypes(
        down: .leftMouseDown,
        dragged: .leftMouseDragged,
        up: .leftMouseUp
      )
    )

    XCTAssertEqual(
      PointerButton.secondary.cgEventTypes,
      PointerButtonCGEventTypes(
        down: .rightMouseDown,
        dragged: .rightMouseDragged,
        up: .rightMouseUp
      )
    )

    XCTAssertEqual(
      PointerButton.middle.cgEventTypes,
      PointerButtonCGEventTypes(
        down: .otherMouseDown,
        dragged: .otherMouseDragged,
        up: .otherMouseUp
      )
    )
  }

  func testAdditionalPointerButtonMapsOtherMouseEventTypes() throws {
    let button = try XCTUnwrap(PointerButton(additionalButtonNumber: 4))

    XCTAssertEqual(
      button.cgEventTypes,
      PointerButtonCGEventTypes(
        down: .otherMouseDown,
        dragged: .otherMouseDragged,
        up: .otherMouseUp
      )
    )
  }
}
