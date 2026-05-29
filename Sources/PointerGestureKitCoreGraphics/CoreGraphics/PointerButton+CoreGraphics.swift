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
      self.init(additionalButtonNumber: UInt32(cgButtonNumber))
    }
  }

  var cgMouseButton: CGMouseButton? {
    if self == .primary { return .left }
    if self == .secondary { return .right }
    if self == .middle { return .center }
    guard let additionalButtonNumber else { return nil }
    return CGMouseButton(rawValue: additionalButtonNumber)
  }

  var usesOtherMouseEventTypes: Bool {
    self == .middle || additionalButtonNumber != nil
  }

  var cgEventTypes: PointerButtonCGEventTypes {
    if self == .primary {
      return PointerButtonCGEventTypes(
        down: .leftMouseDown,
        dragged: .leftMouseDragged,
        up: .leftMouseUp
      )
    }
    if self == .secondary {
      return PointerButtonCGEventTypes(
        down: .rightMouseDown,
        dragged: .rightMouseDragged,
        up: .rightMouseUp
      )
    }
    return PointerButtonCGEventTypes(
      down: .otherMouseDown,
      dragged: .otherMouseDragged,
      up: .otherMouseUp
    )
  }
}

struct PointerButtonCGEventTypes: Equatable, Sendable {
  let down: CGEventType
  let dragged: CGEventType
  let up: CGEventType
}
