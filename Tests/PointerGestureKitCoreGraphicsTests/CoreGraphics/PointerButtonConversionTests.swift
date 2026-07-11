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
      PointerButton(auxiliaryButtonID: 3)
    )

    XCTAssertNil(PointerButton(cgButtonNumber: -1))
    XCTAssertNil(PointerButton(cgButtonNumber: Int64(UInt32.max) + 1))
  }

  func testPointerButtonMapsCoreGraphicsMouseButtonsForReplay() throws {
    let auxiliaryButton = try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))

    XCTAssertEqual(PointerButton.primary.cgMouseButton, .left)
    XCTAssertEqual(PointerButton.secondary.cgMouseButton, .right)
    XCTAssertEqual(PointerButton.middle.cgMouseButton, .center)
    XCTAssertEqual(auxiliaryButton.cgMouseButton, CGMouseButton(rawValue: 4))
  }

  func testPointerButtonMapsCoreGraphicsEventFamiliesForCaptureAndReplay() throws {
    assertEventTypes(
      PointerButton.primary.cgEventTypes,
      down: .leftMouseDown,
      moved: .leftMouseDragged,
      up: .leftMouseUp
    )
    assertEventTypes(
      PointerButton.secondary.cgEventTypes,
      down: .rightMouseDown,
      moved: .rightMouseDragged,
      up: .rightMouseUp
    )
    assertEventTypes(
      PointerButton.middle.cgEventTypes,
      down: .otherMouseDown,
      moved: .otherMouseDragged,
      up: .otherMouseUp
    )
    let auxiliaryButton = try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))
    assertEventTypes(
      auxiliaryButton.cgEventTypes,
      down: .otherMouseDown,
      moved: .otherMouseDragged,
      up: .otherMouseUp
    )
  }
}

private func assertEventTypes(
  _ eventTypes: PointerButtonCGEventTypes,
  down: CGEventType,
  moved: CGEventType,
  up: CGEventType,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertEqual(eventTypes.down, down, file: file, line: line)
  XCTAssertEqual(eventTypes.moved, moved, file: file, line: line)
  XCTAssertEqual(eventTypes.up, up, file: file, line: line)
}
