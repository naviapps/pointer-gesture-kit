/// A platform-neutral pointer button.
public struct PointerButton: Hashable, Sendable {
  private enum Storage: Hashable, Sendable {
    case primary
    case secondary
    case middle
    case additional(UInt32)
  }

  /// The primary pointer button, commonly the left mouse button.
  public static let primary = Self(storage: .primary)
  /// The secondary pointer button, commonly the right mouse button.
  public static let secondary = Self(storage: .secondary)
  /// The middle pointer button.
  public static let middle = Self(storage: .middle)

  private let storage: Storage

  /// The button number for an additional pointer button.
  ///
  /// Primary, secondary, and middle buttons return `nil` because they are modeled explicitly.
  public var additionalButtonNumber: UInt32? {
    guard case let .additional(buttonNumber) = storage else { return nil }
    return buttonNumber
  }

  /// Creates an additional pointer button.
  ///
  /// Returns `nil` for button numbers already modeled by ``primary``, ``secondary``, and
  /// ``middle``.
  public init?(additionalButtonNumber: UInt32) {
    guard additionalButtonNumber > 2 else { return nil }
    storage = .additional(additionalButtonNumber)
  }

  private init(storage: Storage) {
    self.storage = storage
  }
}
