import Foundation

/// Tuning values for gesture recognition and event-source start retry.
public struct GestureRecognizerTuning: Hashable, Sendable {
  /// Minimum horizontal or vertical movement needed before a gesture starts capturing directions.
  public let minimumGestureStartAxisDistance: Double
  /// Minimum horizontal or vertical movement needed before accepting a new direction.
  public let minimumDirectionChangeAxisDistance: Double
  /// Maximum duration allowed for a gesture session.
  ///
  /// `nil` disables gesture-session expiration.
  public let maximumGestureSessionDuration: TimeInterval?
  /// Maximum number of raw pointer points retained for an active gesture.
  public let maximumRawPointCount: Int
  /// Delays used when retrying event-source start after start fails.
  ///
  /// An empty array disables scheduled retry. A zero delay retries on the next task yield.
  public let eventSourceStartRetryDelays: [TimeInterval]

  /// Creates tuning values, normalizing invalid numeric inputs at the package boundary.
  ///
  /// Non-finite or negative axis distances become zero. Non-positive or non-finite gesture session
  /// durations become `nil`. Negative and non-finite retry delays are discarded; explicit zero
  /// retry delays are preserved as next-yield retries. Empty retry delay arrays stay empty, and the
  /// raw point count is clamped to at least one.
  public init(
    minimumGestureStartAxisDistance: Double = 10.0,
    minimumDirectionChangeAxisDistance: Double = 25.0,
    maximumGestureSessionDuration: TimeInterval? = 10.0,
    maximumRawPointCount: Int = 1000,
    eventSourceStartRetryDelays: [TimeInterval] = [0.25, 0.5, 1.0, 2.0, 4.0]
  ) {
    self.minimumGestureStartAxisDistance = Self.nonNegativeFiniteAxisDistance(
      minimumGestureStartAxisDistance)
    self.minimumDirectionChangeAxisDistance = Self.nonNegativeFiniteAxisDistance(
      minimumDirectionChangeAxisDistance
    )
    self.maximumGestureSessionDuration = maximumGestureSessionDuration.flatMap(
      Self.positiveFiniteDuration
    )
    self.maximumRawPointCount = max(1, maximumRawPointCount)
    self.eventSourceStartRetryDelays = eventSourceStartRetryDelays.compactMap(
      Self.nonNegativeFiniteDelay
    )
  }

  private static func nonNegativeFiniteAxisDistance(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return max(0, value)
  }

  private static func positiveFiniteDuration(_ value: TimeInterval) -> TimeInterval? {
    guard value.isFinite, value > 0 else { return nil }
    return value
  }

  private static func nonNegativeFiniteDelay(_ value: TimeInterval) -> TimeInterval? {
    guard value.isFinite, value >= 0 else { return nil }
    return value
  }
}
