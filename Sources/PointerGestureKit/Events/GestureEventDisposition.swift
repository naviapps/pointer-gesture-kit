/// The action an event source applies to the original platform event after delivering normalized
/// gesture input.
public enum GestureEventDisposition: Equatable, Sendable {
  /// Suppresses the original platform event after the normalized event is handled.
  case consume

  /// Leaves the original platform event in the platform event stream.
  case passThrough

  /// Whether the original platform event should be suppressed after the normalized event is handled.
  public var consumesOriginalEvent: Bool {
    switch self {
    case .consume:
      true
    case .passThrough:
      false
    }
  }
}
