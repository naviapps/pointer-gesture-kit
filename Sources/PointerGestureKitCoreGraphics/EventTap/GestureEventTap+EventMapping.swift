import class CoreGraphics.CGEvent
import struct CoreGraphics.CGEventFlags
import enum CoreGraphics.CGEventField
import typealias CoreGraphics.CGEventMask
import enum CoreGraphics.CGEventType
import PointerGestureKit

extension GestureEventTap {
  nonisolated var eventMask: CGEventMask {
    guard !capturedButtons.isEmpty else { return 0 }

    var eventTypes = Set<CGEventType>()
    eventTypes.insert(.keyDown)
    for button in capturedButtons {
      let buttonEventTypes = button.cgEventTypes
      eventTypes.insert(buttonEventTypes.down)
      eventTypes.insert(buttonEventTypes.dragged)
      eventTypes.insert(buttonEventTypes.up)
    }
    return eventTapMask(for: eventTypes)
  }

  nonisolated func inputEvent(for type: CGEventType, event: CGEvent) -> GestureInputEvent? {
    mappedInputEvent(for: type, event: event)?.input
  }

  nonisolated func mappedInputEvent(for type: CGEventType, event: CGEvent) -> MappedInputEvent? {
    guard !capturedButtons.isEmpty else { return nil }

    if type == .keyDown {
      guard event.getIntegerValueField(.keyboardEventKeycode) == escapeVirtualKeyCode else {
        return nil
      }
      return makeMappedInputEvent(kind: .cancel, button: nil, type: type, event: event)
    }

    guard let mapping = pointerButtonInput(for: type, event: event) else {
      return nil
    }
    guard capturedButtons.contains(mapping.button) else { return nil }
    return makeMappedInputEvent(
      kind: mapping.kind(mapping.button),
      button: mapping.button,
      type: type,
      event: event
    )
  }

  private nonisolated func makeMappedInputEvent(
    kind: GestureInputEvent.Kind,
    button: PointerButton?,
    type: CGEventType,
    event: CGEvent
  ) -> MappedInputEvent {
    MappedInputEvent(
      input: GestureInputEvent(
        kind: kind,
        location: GesturePoint(event.location),
        modifiers: gestureModifierFlags(from: event.flags)
      ),
      sourceSignature: SyntheticEventSignature.observed(
        type: type,
        button: button,
        eventSourceUserData: event.getIntegerValueField(.eventSourceUserData)
      )
    )
  }
}

struct MappedInputEvent: Sendable {
  let input: GestureInputEvent
  let sourceSignature: SyntheticEventSignature
}

private struct PointerButtonInputMapping {
  let kind: (PointerButton) -> GestureInputEvent.Kind
  let button: PointerButton
}

private let escapeVirtualKeyCode: Int64 = 53

private func eventTapMask(for types: some Sequence<CGEventType>) -> CGEventMask {
  types.reduce(0) { mask, type in
    mask | (1 << type.rawValue)
  }
}

private func pointerButtonInput(
  for type: CGEventType,
  event: CGEvent
) -> PointerButtonInputMapping? {
  switch type {
  case .leftMouseDown:
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonDown, button: .primary)
  case .leftMouseDragged:
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonDragged, button: .primary)
  case .leftMouseUp:
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonUp, button: .primary)
  case .rightMouseDown:
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonDown, button: .secondary)
  case .rightMouseDragged:
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonDragged, button: .secondary)
  case .rightMouseUp:
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonUp, button: .secondary)
  case .otherMouseDown:
    guard let button = otherPointerButton(for: event) else { return nil }
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonDown, button: button)
  case .otherMouseDragged:
    guard let button = otherPointerButton(for: event) else { return nil }
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonDragged, button: button)
  case .otherMouseUp:
    guard let button = otherPointerButton(for: event) else { return nil }
    return PointerButtonInputMapping(kind: GestureInputEvent.Kind.buttonUp, button: button)
  default:
    return nil
  }
}

private func otherPointerButton(for event: CGEvent) -> PointerButton? {
  guard let button = pointerButton(for: event), button.usesOtherMouseEventTypes else { return nil }
  return button
}

private func pointerButton(for event: CGEvent) -> PointerButton? {
  PointerButton(cgButtonNumber: event.getIntegerValueField(.mouseEventButtonNumber))
}

private func gestureModifierFlags(from flags: CGEventFlags) -> GestureModifierFlags {
  var result = GestureModifierFlags()
  if flags.contains(.maskCommand) { result.insert(.command) }
  if flags.contains(.maskAlternate) { result.insert(.option) }
  if flags.contains(.maskControl) { result.insert(.control) }
  if flags.contains(.maskShift) { result.insert(.shift) }
  return result
}
