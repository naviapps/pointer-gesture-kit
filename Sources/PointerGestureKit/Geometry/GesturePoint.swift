/// A finite point in gesture coordinate space.
///
/// Gesture direction recognition treats positive vertical movement as downward.
public struct GesturePoint: Hashable, Sendable {
  /// The horizontal coordinate.
  public let x: Double
  /// The vertical coordinate.
  public let y: Double

  /// Creates a gesture point, replacing non-finite coordinates with zero.
  public init(x: Double, y: Double) {
    self.x = Self.finite(x)
    self.y = Self.finite(y)
  }

  /// The origin point.
  public static let zero = GesturePoint(x: 0, y: 0)

  private static func finite(_ value: Double) -> Double {
    value.isFinite ? value : 0
  }
}
