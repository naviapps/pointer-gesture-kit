/// Known platform-neutral modifier keys captured with a gesture event.
public struct GestureModifierFlags: OptionSet, Hashable, Sendable {
  /// The raw option-set value with unknown modifier bits removed.
  public let rawValue: Int

  /// Creates modifier flags from a raw option-set value, discarding unknown bits.
  public init(rawValue: Int) {
    self.rawValue = rawValue & Self.knownRawMask
  }

  /// The Command key.
  public static let command = GestureModifierFlags(rawValue: commandRawValue)
  /// The Option key.
  public static let option = GestureModifierFlags(rawValue: optionRawValue)
  /// The Control key.
  public static let control = GestureModifierFlags(rawValue: controlRawValue)
  /// The Shift key.
  public static let shift = GestureModifierFlags(rawValue: shiftRawValue)

  private static let commandRawValue = 1 << 0
  private static let optionRawValue = 1 << 1
  private static let controlRawValue = 1 << 2
  private static let shiftRawValue = 1 << 3
  private static let knownRawMask =
    commandRawValue | optionRawValue | controlRawValue | shiftRawValue
}
