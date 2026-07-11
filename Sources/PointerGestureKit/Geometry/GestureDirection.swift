/// A cardinal direction in a pointer gesture pattern or trace.
public enum GestureDirection: Hashable, Sendable {
  /// Movement toward a decreasing y coordinate.
  case up
  /// Movement toward an increasing y coordinate.
  case down
  /// Movement toward a decreasing x coordinate.
  case left
  /// Movement toward an increasing x coordinate.
  case right
}
