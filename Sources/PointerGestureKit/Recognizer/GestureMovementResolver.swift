enum GestureMovementResolver {
  /// Returns the larger absolute coordinate delta between two points.
  static func maximumAxisDelta(from start: GesturePoint, to end: GesturePoint) -> Double {
    max(abs(end.x - start.x), abs(end.y - start.y))
  }

  /// Returns the dominant cardinal direction between two points.
  static func dominantDirection(
    from start: GesturePoint,
    to end: GesturePoint
  ) -> GestureDirection? {
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y

    let absoluteDeltaX = abs(deltaX)
    let absoluteDeltaY = abs(deltaY)

    guard absoluteDeltaX != absoluteDeltaY else {
      return nil
    }

    if absoluteDeltaX > absoluteDeltaY {
      return deltaX >= 0 ? .right : .left
    } else {
      // Gesture coordinates treat positive Y as downward.
      return deltaY >= 0 ? .down : .up
    }
  }
}
