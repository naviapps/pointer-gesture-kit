import struct CoreGraphics.CGFloat
import struct CoreGraphics.CGPoint
import PointerGestureKit

extension GesturePoint {
  /// Creates a gesture point from a Core Graphics point.
  public init(_ point: CGPoint) {
    self.init(x: Double(point.x), y: Double(point.y))
  }

  /// Converts the gesture point to a Core Graphics point.
  public var cgPoint: CGPoint {
    CGPoint(x: CGFloat(x), y: CGFloat(y))
  }
}
