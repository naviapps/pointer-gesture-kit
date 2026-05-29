/// A platform-neutral request to replay consumed pointer-button input.
public enum GestureReplayRequest: Hashable, Sendable {
  /// A request to replay a full pointer-button click at the provided location.
  case click(button: PointerButton, at: GesturePoint)
  /// A request to replay a consumed pointer-button down, drag, and release sequence.
  case drag(button: PointerButton, points: [GesturePoint])
  /// A request to replay only the pointer-button release at the provided location.
  case release(button: PointerButton, at: GesturePoint)

  static func consumedButtonInput(
    button: PointerButton,
    points: [GesturePoint],
    clickAt point: GesturePoint
  ) -> Self {
    points.count > 1
      ? .drag(button: button, points: points)
      : .click(button: button, at: point)
  }

  /// The pointer button used by the replay request.
  public var button: PointerButton {
    switch self {
    case let .click(button, _), let .drag(button, _), let .release(button, _):
      button
    }
  }

  /// The final location affected by the replay request.
  ///
  /// Empty drag requests have no replay location.
  public var location: GesturePoint? {
    switch self {
    case let .click(_, location), let .release(_, location):
      location
    case let .drag(_, points):
      points.last
    }
  }
}
