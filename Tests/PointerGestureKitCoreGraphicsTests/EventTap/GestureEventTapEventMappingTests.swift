import class CoreGraphics.CGEvent
import struct CoreGraphics.CGPoint
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

    let input = inputEvent(from: tap, for: .rightMouseDown, event: event)

    assertInputKind(input?.kind, .buttonDown(.secondary))
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

    let input = inputEvent(from: tap, for: .leftMouseDown, event: event)

    assertInputKind(input?.kind, .buttonDown(.primary))
    XCTAssertEqual(input?.location, GesturePoint(x: 12, y: 34))
  }

  func testInputEventMapsMiddleMouseDownWhenCaptured() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])
    let event = try mouseEvent(type: .otherMouseDown, button: .center)

    let input = inputEvent(from: tap, for: .otherMouseDown, event: event)

    assertInputKind(input?.kind, .buttonDown(.middle))
  }

  func testInputEventMapsOtherMouseDownWhenCaptured() throws {
    let auxiliaryButton = try makeAuxiliaryButton()
    let tap = GestureEventTap(capturedButtons: [auxiliaryButton])
    let event = try mouseEvent(type: .otherMouseDown, button: makeExtraMouseButton())

    let input = inputEvent(from: tap, for: .otherMouseDown, event: event)

    assertInputKind(input?.kind, .buttonDown(auxiliaryButton))
  }

  func testMappedInputEventUsesRecognizedOtherMouseButtonForSourceSignature() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])
    let event = try mouseEvent(type: .otherMouseDown, button: .center)
    SyntheticEventSignature.markReplayed(event)

    let mappedInputEvent = tap.mappedInputEvent(for: .otherMouseDown, event: event)

    assertInputKind(mappedInputEvent?.input.kind, .buttonDown(.middle))
    XCTAssertEqual(
      mappedInputEvent?.sourceSignature,
      SyntheticEventSignature.replayed(type: .otherMouseDown, button: .middle)
    )
  }

  func testInputEventMapsConfiguredMoveCGEventsToButtonMovedInput() throws {
    let auxiliaryButton = try makeAuxiliaryButton()

    try assertInputEventMapsMovedAndUp(
      capturedButton: .secondary,
      movedEventType: .rightMouseDragged,
      upType: .rightMouseUp,
      mouseButton: .right
    )
    try assertInputEventMapsMovedAndUp(
      capturedButton: .primary,
      movedEventType: .leftMouseDragged,
      upType: .leftMouseUp,
      mouseButton: .left
    )
    try assertInputEventMapsMovedAndUp(
      capturedButton: .middle,
      movedEventType: .otherMouseDragged,
      upType: .otherMouseUp,
      mouseButton: .center
    )
    try assertInputEventMapsMovedAndUp(
      capturedButton: auxiliaryButton,
      movedEventType: .otherMouseDragged,
      upType: .otherMouseUp,
      mouseButton: makeExtraMouseButton()
    )
  }

  func testInputEventMapsSupportedModifiers() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(type: .rightMouseDown, button: .right)
    event.flags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]

    let input = inputEvent(from: tap, for: .rightMouseDown, event: event)

    XCTAssertEqual(input?.modifiers, [.command, .option, .control, .shift])
  }

  func testInputEventDropsUnsupportedModifiers() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(type: .rightMouseDown, button: .right)
    event.flags = [.maskCommand, .maskSecondaryFn]

    let input = inputEvent(from: tap, for: .rightMouseDown, event: event)

    XCTAssertEqual(input?.modifiers, [.command])
  }

  func testInputEventMapsEscapeKeyDownToCancel() throws {
    let tap = GestureEventTap()
    let event = try XCTUnwrap(
      CGEvent(keyboardEventSource: nil, virtualKey: escapeVirtualKeyCode, keyDown: true)
    )
    event.flags = [.maskControl]

    let input = inputEvent(from: tap, for: .keyDown, event: event)

    assertInputKind(input?.kind, .cancel)
    XCTAssertEqual(input?.modifiers, [.control])
  }

  func testTapDisabledEventsMapToCancelInput() throws {
    let tap = GestureEventTap()
    let event = try mouseEvent(type: .rightMouseDragged, button: .right)
    event.flags = [.maskShift]

    let timeoutInput = tap.mappedTapDisabledInputEvent(
      for: .tapDisabledByTimeout,
      event: event
    )?.input
    let userInput = tap.mappedTapDisabledInputEvent(
      for: .tapDisabledByUserInput,
      event: event
    )?.input

    assertInputKind(timeoutInput?.kind, .cancel)
    assertInputKind(userInput?.kind, .cancel)
    XCTAssertEqual(timeoutInput?.modifiers, [.shift])
    XCTAssertEqual(userInput?.modifiers, [.shift])
  }

  func testInputEventIgnoresNonEscapeKeyDown() throws {
    let tap = GestureEventTap()
    let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

    XCTAssertNil(inputEvent(from: tap, for: .keyDown, event: event))
  }

  func testInputEventIgnoresEscapeKeyDownWhenCapturedButtonsAreEmpty() throws {
    let tap = GestureEventTap(capturedButtons: [])
    let event = try XCTUnwrap(
      CGEvent(keyboardEventSource: nil, virtualKey: escapeVirtualKeyCode, keyDown: true)
    )

    XCTAssertNil(inputEvent(from: tap, for: .keyDown, event: event))
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

    XCTAssertNil(inputEvent(from: tap, for: .leftMouseDown, event: event))
  }

  func testInputEventIgnoresUncapturedOtherMouseButton() throws {
    let tap = GestureEventTap(capturedButtons: [.middle])
    let event = try mouseEvent(type: .otherMouseDown, button: makeExtraMouseButton())

    XCTAssertNil(inputEvent(from: tap, for: .otherMouseDown, event: event))
  }

  func testInputEventIgnoresOtherMouseEventsForPrimaryOrSecondaryButtonNumbers() throws {
    let tap = GestureEventTap(capturedButtons: [.primary, .secondary, .middle])

    XCTAssertNil(
      inputEvent(
        from: tap,
        for: .otherMouseDown,
        event: try mouseEvent(type: .otherMouseDown, button: .left))
    )
    XCTAssertNil(
      inputEvent(
        from: tap,
        for: .otherMouseDown,
        event: try mouseEvent(type: .otherMouseDown, button: .right))
    )
  }
}

private let escapeVirtualKeyCode: UInt16 = 53
private let defaultMouseLocation = CGPoint(x: 12, y: 34)

private func inputEvent(
  from tap: GestureEventTap,
  for type: CGEventType,
  event: CGEvent
) -> GestureInputEvent? {
  tap.mappedInputEvent(for: type, event: event)?.input
}

@MainActor
private func assertInputEventMapsMovedAndUp(
  capturedButton: PointerButton,
  movedEventType: CGEventType,
  upType: CGEventType,
  mouseButton: CGMouseButton,
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  let tap = GestureEventTap(capturedButtons: [capturedButton])

  let moved = inputEvent(
    from: tap,
    for: movedEventType,
    event: try mouseEvent(type: movedEventType, button: mouseButton)
  )
  let up = inputEvent(
    from: tap,
    for: upType,
    event: try mouseEvent(type: upType, button: mouseButton)
  )

  assertInputKind(moved?.kind, .buttonMoved(capturedButton), file: file, line: line)
  assertInputKind(up?.kind, .buttonUp(capturedButton), file: file, line: line)
}

private func makeExtraMouseButton() throws -> CGMouseButton {
  try XCTUnwrap(CGMouseButton(rawValue: 4))
}

private func makeAuxiliaryButton() throws -> PointerButton {
  try XCTUnwrap(PointerButton(auxiliaryButtonID: 4))
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

private func eventTapMask(for types: CGEventType...) -> UInt64 {
  types.reduce(0) { mask, type in
    mask | (1 << type.rawValue)
  }
}

private func assertInputKind(
  _ kind: GestureInputEvent.Kind?,
  _ expected: ExpectedInputKind,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  guard let kind else {
    XCTFail("Expected input kind \(expected)", file: file, line: line)
    return
  }

  switch (kind, expected) {
  case let (.buttonDown(button), .buttonDown(expectedButton)):
    XCTAssertEqual(button, expectedButton, file: file, line: line)
  case let (.buttonMoved(button), .buttonMoved(expectedButton)):
    XCTAssertEqual(button, expectedButton, file: file, line: line)
  case let (.buttonUp(button), .buttonUp(expectedButton)):
    XCTAssertEqual(button, expectedButton, file: file, line: line)
  case (.cancel, .cancel):
    break
  default:
    XCTFail("Unexpected input kind \(kind)", file: file, line: line)
  }
}

private enum ExpectedInputKind {
  case buttonDown(PointerButton)
  case buttonMoved(PointerButton)
  case buttonUp(PointerButton)
  case cancel
}
