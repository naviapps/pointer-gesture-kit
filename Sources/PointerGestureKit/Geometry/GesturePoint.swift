/// A point in gesture coordinate space.
///
/// Gesture direction recognition treats positive vertical movement as downward.
public struct GesturePoint: Equatable, Sendable {
  /// The horizontal coordinate.
  public let x: Double
  /// The vertical coordinate.
  public let y: Double

  /// Creates a gesture point.
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  /// The origin point.
  public static let zero = GesturePoint(x: 0, y: 0)

  /// Whether both coordinates are finite and safe for recognition or platform replay.
  public var isFinite: Bool {
    x.isFinite && y.isFinite
  }
}
