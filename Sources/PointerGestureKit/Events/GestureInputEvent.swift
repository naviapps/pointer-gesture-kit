/// A platform-neutral pointer or semantic cancel event used by the recognizer.
public struct GestureInputEvent: Hashable, Sendable {
  /// The normalized event kind.
  public enum Kind: Hashable, Sendable {
    /// A pointer button was pressed.
    case buttonDown(PointerButton)
    /// A pointer button moved while pressed.
    case buttonDragged(PointerButton)
    /// A pointer button was released.
    case buttonUp(PointerButton)
    /// A semantic cancel event occurred.
    ///
    /// Event-source implementations may map platform-specific cancel input to this semantic event.
    case cancel
  }

  /// The kind of input event.
  public let kind: Kind
  /// The event location in the event source's coordinate space.
  ///
  /// For semantic cancel events, this is the source's best available location.
  public let location: GesturePoint
  /// Modifier flags active when the event was captured.
  public let modifiers: GestureModifierFlags

  /// Creates an input event.
  public init(kind: Kind, location: GesturePoint, modifiers: GestureModifierFlags = []) {
    self.kind = kind
    self.location = location
    self.modifiers = modifiers
  }
}
