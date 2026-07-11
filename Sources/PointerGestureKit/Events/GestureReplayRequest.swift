/// A platform-neutral request to replay consumed pointer-button input.
public enum GestureReplayRequest: Equatable, Sendable {
  /// A request to replay a full pointer-button click at the provided location.
  case click(button: PointerButton, at: GesturePoint)
  /// A request to replay consumed pointer-button locations as a drag sequence.
  ///
  /// Platform adapters decide how to map the ordered locations, including empty and single-point
  /// requests, to concrete events.
  case drag(button: PointerButton, points: [GesturePoint])
  /// A request to replay the beginning of a consumed pointer-button drag without a release.
  ///
  /// Use this when recognition stops before the physical button is released. Platform adapters
  /// should replay the button-down and consumed drag movement, then allow later real events through.
  case dragStart(button: PointerButton, points: [GesturePoint])
  /// A request to replay only the pointer-button release at the provided location.
  case release(button: PointerButton, at: GesturePoint)
}
