/// Indicates how an event source should handle the original platform event.
public enum GestureEventDisposition: Hashable, Sendable {
  /// Suppresses the original platform event after the normalized event is handled.
  case consume
  /// Leaves the original platform event in the platform event stream.
  case passThrough
}
