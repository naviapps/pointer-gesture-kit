/// A platform-neutral pointer button.
public struct PointerButton: Hashable, Sendable {
  private enum Storage: Hashable, Sendable {
    case primary
    case secondary
    case middle
    case auxiliary(UInt32)
  }

  /// The primary pointer button.
  public static let primary = Self(storage: .primary)
  /// The secondary pointer button.
  public static let secondary = Self(storage: .secondary)
  /// The middle pointer button.
  public static let middle = Self(storage: .middle)

  private let storage: Storage

  /// The platform-neutral identifier for an auxiliary pointer button.
  ///
  /// Primary, secondary, and middle buttons return `nil` because they are modeled explicitly.
  public var auxiliaryButtonID: UInt32? {
    guard case let .auxiliary(buttonID) = storage else { return nil }
    return buttonID
  }

  /// Creates an auxiliary pointer button.
  ///
  /// Returns `nil` for identifiers already modeled by ``primary``, ``secondary``, and
  /// ``middle``.
  public init?(auxiliaryButtonID: UInt32) {
    guard auxiliaryButtonID > 2 else { return nil }
    storage = .auxiliary(auxiliaryButtonID)
  }

  private init(storage: Storage) {
    self.storage = storage
  }
}
