/// Package-owned modifier flags captured with a gesture event.
///
/// Known flags use package-owned bit positions, not platform modifier-mask values.
public struct GestureModifierFlags: OptionSet, Hashable, Sendable {
  /// The raw option-set value.
  public let rawValue: Int

  /// Creates modifier flags from a raw option-set value.
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  /// The Command modifier captured with a gesture event.
  public static let command = GestureModifierFlags(rawValue: commandRawValue)
  /// The Option modifier captured with a gesture event.
  public static let option = GestureModifierFlags(rawValue: optionRawValue)
  /// The Control modifier captured with a gesture event.
  public static let control = GestureModifierFlags(rawValue: controlRawValue)
  /// The Shift modifier captured with a gesture event.
  public static let shift = GestureModifierFlags(rawValue: shiftRawValue)

  private static let commandRawValue = 1 << 0
  private static let optionRawValue = 1 << 1
  private static let controlRawValue = 1 << 2
  private static let shiftRawValue = 1 << 3
}
