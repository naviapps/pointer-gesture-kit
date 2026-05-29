import class CoreGraphics.CGEvent
import struct CoreGraphics.CGPoint
import typealias CoreGraphics.CGEventMask
import typealias CoreGraphics.CGKeyCode
import enum CoreGraphics.CGEventType
import enum CoreGraphics.CGMouseButton
import PointerGestureKit
import XCTest

@testable import PointerGestureKitCoreGraphics

@MainActor
final class GestureEventTapEventMappingTests: XCTestCase {
  func testEventMaskMatchesSupportedGestureEvents() {
    let tap = GestureEventTap()

    XCTAssertEqual(
      tap.eventMask,
      eventTapMask(for: .rightMouseDown, .rightMouseDragged, .rightMouseUp, .keyDown)
    )
  }

  func testEmptyCapturedButtonsCaptureNoEvents() {
    let tap = GestureEventTap(capturedButtons: [])

    XCTAssertEqual(tap.eventMask, 0)
  }

  func testEventMaskMatchesConfiguredPrimaryAndOtherButtonEvents() {
    let tap = GestureEventTap(capturedButtons: [.primary, .middle])

    XCTAssertEqual(
      tap.eventMask,
      eventTapMask(
        for: .leftMouseDown, .leftMouseDragged, .leftMouseUp, .otherMouseDown, .otherMouseDragged,
        .otherMouseUp, .keyDown)
    )
  }

  func testInputEventMapsSecondaryMouseDown() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(
      type: .rightMouseDown,
      button: .right,
      location: CGPoint(x: 12, y: 34)
    )
    event.flags = [.maskCommand, .maskShift]

    let input = tap.inputEvent(for: .rightMouseDown, event: event)

    XCTAssertEqual(input?.kind, .buttonDown(.secondary))
    XCTAssertEqual(input?.location, GesturePoint(x: 12, y: 34))
    XCTAssertEqual(input?.modifiers, [.command, .shift])
  }

  func testInputEventMapsPrimaryMouseDownWhenCaptured() throws {
    let tap = GestureEventTap(capturedButtons: [.primary])
    let event = try mouseEvent(
      type: .leftMouseDown,
      button: .left,
      location: CGPoint(x: 12, y: 34)
    )

    let input = tap.inputEvent(for: .leftMouseDown, event: event)

    XCTAssertEqual(input?.kind, .buttonDown(.primary))
    XCTAssertEqual(input?.location, GesturePoint(x: 12, y: 34))
  }

  func testInputEventMapsPrimaryMouseDraggedAndUpWhenCaptured() throws {
    let tap = GestureEventTap(capturedButtons: [.primary])

    let dragged = tap.inputEvent(
      for: .leftMouseDragged,
      event: try mouseEvent(type: .leftMouseDragged, button: .left)
    )
    let up = tap.inputEvent(
      for: .leftMouseUp,
      event: try mouseEvent(type: .leftMouseUp, button: .left)
    )

    XCTAssertEqual(dragged?.kind, .buttonDragged(.primary))
    XCTAssertEqual(up?.kind, .buttonUp(.primary))
  }

  func testInputEventMapsMiddleMouseDownWhenCaptured() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])
    let event = try mouseEvent(type: .otherMouseDown, button: .center)

    let input = tap.inputEvent(for: .otherMouseDown, event: event)

    XCTAssertEqual(input?.kind, .buttonDown(.middle))
  }

  func testInputEventMapsMiddleMouseDraggedAndUpWhenCaptured() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])

    let dragged = tap.inputEvent(
      for: .otherMouseDragged,
      event: try mouseEvent(type: .otherMouseDragged, button: .center)
    )
    let up = tap.inputEvent(
      for: .otherMouseUp,
      event: try mouseEvent(type: .otherMouseUp, button: .center)
    )

    XCTAssertEqual(dragged?.kind, .buttonDragged(.middle))
    XCTAssertEqual(up?.kind, .buttonUp(.middle))
  }

  func testInputEventMapsOtherMouseDownWhenCaptured() throws {
    let additionalButton = try makeAdditionalButton()
    let tap = GestureEventTap(capturedButtons: [additionalButton])
    let event = try mouseEvent(type: .otherMouseDown, button: makeExtraMouseButton())

    let input = tap.inputEvent(for: .otherMouseDown, event: event)

    XCTAssertEqual(input?.kind, .buttonDown(additionalButton))
  }

  func testMappedInputEventUsesRecognizedOtherMouseButtonForSourceSignature() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])
    let event = try mouseEvent(type: .otherMouseDown, button: .center)
    SyntheticEventSignature.markReplayed(event)

    let mappedInputEvent = tap.mappedInputEvent(for: .otherMouseDown, event: event)

    XCTAssertEqual(mappedInputEvent?.input.kind, .buttonDown(.middle))
    XCTAssertEqual(
      mappedInputEvent?.sourceSignature,
      SyntheticEventSignature.replayed(type: .otherMouseDown, button: .middle)
    )
  }

  func testInputEventMapsOtherMouseDraggedAndUpWhenCaptured() throws {
    let additionalButton = try makeAdditionalButton()
    let tap = GestureEventTap(capturedButtons: [additionalButton])

    let dragged = tap.inputEvent(
      for: .otherMouseDragged,
      event: try mouseEvent(type: .otherMouseDragged, button: makeExtraMouseButton())
    )
    let up = tap.inputEvent(
      for: .otherMouseUp,
      event: try mouseEvent(type: .otherMouseUp, button: makeExtraMouseButton())
    )

    XCTAssertEqual(dragged?.kind, .buttonDragged(additionalButton))
    XCTAssertEqual(up?.kind, .buttonUp(additionalButton))
  }

  func testInputEventMapsSupportedModifiers() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(type: .rightMouseDown, button: .right)
    event.flags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]

    let input = tap.inputEvent(for: .rightMouseDown, event: event)

    XCTAssertEqual(input?.modifiers, [.command, .option, .control, .shift])
  }

  func testInputEventDropsUnsupportedModifiers() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(type: .rightMouseDown, button: .right)
    event.flags = [.maskCommand, .maskSecondaryFn]

    let input = tap.inputEvent(for: .rightMouseDown, event: event)

    XCTAssertEqual(input?.modifiers, [.command])
  }

  func testInputEventMapsSecondaryMouseDragged() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(
      type: .rightMouseDragged,
      button: .right,
      location: CGPoint(x: 18, y: 21)
    )

    let input = tap.inputEvent(for: .rightMouseDragged, event: event)

    XCTAssertEqual(input?.kind, .buttonDragged(.secondary))
    XCTAssertEqual(input?.location, GesturePoint(x: 18, y: 21))
  }

  func testInputEventMapsSecondaryMouseUp() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(
      type: .rightMouseUp,
      button: .right,
      location: CGPoint(x: 30, y: 42)
    )

    let input = tap.inputEvent(for: .rightMouseUp, event: event)

    XCTAssertEqual(input?.kind, .buttonUp(.secondary))
    XCTAssertEqual(input?.location, GesturePoint(x: 30, y: 42))
  }

  func testInputEventMapsEscapeKeyDownToCancel() throws {
    let tap = GestureEventTap()
    let event = try XCTUnwrap(
      CGEvent(keyboardEventSource: nil, virtualKey: escapeVirtualKeyCode, keyDown: true)
    )
    event.flags = [.maskControl]

    let input = tap.inputEvent(for: .keyDown, event: event)

    XCTAssertEqual(input?.kind, .cancel)
    XCTAssertEqual(input?.modifiers, [.control])
  }

  func testInputEventIgnoresNonEscapeKeyDown() throws {
    let tap = GestureEventTap()
    let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

    XCTAssertNil(tap.inputEvent(for: .keyDown, event: event))
  }

  func testInputEventIgnoresEscapeKeyDownWhenCapturedButtonsAreEmpty() throws {
    let tap = GestureEventTap(capturedButtons: [])
    let event = try XCTUnwrap(
      CGEvent(keyboardEventSource: nil, virtualKey: escapeVirtualKeyCode, keyDown: true)
    )

    XCTAssertNil(tap.inputEvent(for: .keyDown, event: event))
  }

  func testInputEventIgnoresUncapturedMouseEvent() throws {
    let tap = GestureEventTap()
    let event = try XCTUnwrap(
      CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseDown,
        mouseCursorPosition: CGPoint(x: 12, y: 34),
        mouseButton: .left
      ))

    XCTAssertNil(tap.inputEvent(for: .leftMouseDown, event: event))
  }

  func testInputEventIgnoresUncapturedOtherMouseButton() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])
    let event = try mouseEvent(type: .otherMouseDown, button: makeExtraMouseButton())

    XCTAssertNil(tap.inputEvent(for: .otherMouseDown, event: event))
  }

  func testInputEventIgnoresOtherMouseEventsForPrimaryOrSecondaryButtonNumbers() throws {
    let tap = GestureEventTap(capturedButtons: [.primary, .secondary, .middle])

    XCTAssertNil(
      tap.inputEvent(
        for: .otherMouseDown,
        event: try mouseEvent(type: .otherMouseDown, button: .left))
    )
    XCTAssertNil(
      tap.inputEvent(
        for: .otherMouseDown,
        event: try mouseEvent(type: .otherMouseDown, button: .right))
    )
  }
}

private let escapeVirtualKeyCode: CGKeyCode = 53
private let defaultMouseLocation = CGPoint(x: 12, y: 34)

private func makeExtraMouseButton() throws -> CGMouseButton {
  try XCTUnwrap(CGMouseButton(rawValue: 4))
}

private func makeAdditionalButton() throws -> PointerButton {
  try XCTUnwrap(PointerButton(additionalButtonNumber: 4))
}

private func mouseEvent(
  type: CGEventType,
  button: CGMouseButton,
  location: CGPoint = defaultMouseLocation
) throws -> CGEvent {
  try XCTUnwrap(
    CGEvent(
      mouseEventSource: nil,
      mouseType: type,
      mouseCursorPosition: location,
      mouseButton: button
    ))
}

private func eventTapMask(for types: CGEventType...) -> CGEventMask {
  types.reduce(0) { mask, type in
    mask | (1 << type.rawValue)
  }
}
