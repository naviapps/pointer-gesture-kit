import enum CoreGraphics.CGEventType
import enum CoreGraphics.CGMouseButton
import PointerGestureKit

extension PointerButton {
  init?(cgButtonNumber: Int64) {
    switch cgButtonNumber {
    case 0:
      self = .primary
    case 1:
      self = .secondary
    case 2:
      self = .middle
    default:
      guard cgButtonNumber > 2, cgButtonNumber <= Int64(UInt32.max) else { return nil }
      self.init(auxiliaryButtonID: UInt32(cgButtonNumber))
    }
  }

  var cgMouseButton: CGMouseButton? {
    if self == .primary { return .left }
    if self == .secondary { return .right }
    if self == .middle { return .center }
    guard let auxiliaryButtonID else { return nil }
    return CGMouseButton(rawValue: auxiliaryButtonID)
  }

  var cgEventTypes: PointerButtonCGEventTypes {
    if self == .primary {
      return PointerButtonCGEventTypes(
        down: .leftMouseDown,
        moved: .leftMouseDragged,
        up: .leftMouseUp
      )
    }
    if self == .secondary {
      return PointerButtonCGEventTypes(
        down: .rightMouseDown,
        moved: .rightMouseDragged,
        up: .rightMouseUp
      )
    }
    return PointerButtonCGEventTypes(
      down: .otherMouseDown,
      moved: .otherMouseDragged,
      up: .otherMouseUp
    )
  }
}

struct PointerButtonCGEventTypes: Sendable {
  let down: CGEventType
  let moved: CGEventType
  let up: CGEventType
}
