import Foundation

/// Validated tuning values for gesture recognition and event-source start retry.
public struct GestureRecognizerTuning: Equatable, Sendable {
  /// A reason custom tuning values could not be created.
  public enum ValidationError: Error, Equatable, Sendable {
    /// The gesture-start distance was negative or non-finite.
    case invalidMinimumGestureStartAxisDistance
    /// The direction-change distance was negative or non-finite.
    case invalidMinimumDirectionChangeAxisDistance
    /// The non-`nil` session duration was non-positive or non-finite.
    case invalidMaximumGestureSessionDuration
    /// The raw point count was not positive.
    case invalidMaximumRawPointCount
    /// A retry delay at the zero-based index was negative or non-finite.
    case invalidEventSourceStartRetryDelay(index: Int)
  }

  /// Minimum horizontal or vertical movement needed before a gesture starts.
  public let minimumGestureStartAxisDistance: Double
  /// Minimum horizontal or vertical movement needed before accepting a new direction.
  public let minimumDirectionChangeAxisDistance: Double
  /// Maximum duration for pending or active gesture input, or `nil` to disable expiration.
  public let maximumGestureSessionDuration: TimeInterval?
  /// Maximum number of raw pointer points retained for an active gesture.
  public let maximumRawPointCount: Int
  /// Delays used in order when retrying event-source startup.
  public let eventSourceStartRetryDelays: [TimeInterval]

  /// Recommended production tuning.
  public static let standard = Self(
    minimumGestureStartAxisDistance: 10,
    minimumDirectionChangeAxisDistance: 25,
    maximumGestureSessionDuration: 1,
    maximumRawPointCount: 256,
    eventSourceStartRetryDelays: [0.25, 0.5, 1, 2, 4]
  )

  /// Creates custom tuning after validating every value.
  ///
  /// Distances and retry delays must be finite and nonnegative. A non-`nil` session duration must
  /// be finite and positive. The raw point count must be positive. Retry order and duplicates are
  /// preserved, and an explicit zero delay means retry on the next task yield.
  public static func validated(
    minimumGestureStartAxisDistance: Double = 10,
    minimumDirectionChangeAxisDistance: Double = 25,
    maximumGestureSessionDuration: TimeInterval? = 1,
    maximumRawPointCount: Int = 256,
    eventSourceStartRetryDelays: [TimeInterval] = [0.25, 0.5, 1, 2, 4]
  ) throws -> Self {
    guard minimumGestureStartAxisDistance.isFinite, minimumGestureStartAxisDistance >= 0 else {
      throw ValidationError.invalidMinimumGestureStartAxisDistance
    }
    guard minimumDirectionChangeAxisDistance.isFinite, minimumDirectionChangeAxisDistance >= 0
    else {
      throw ValidationError.invalidMinimumDirectionChangeAxisDistance
    }
    if let maximumGestureSessionDuration {
      guard maximumGestureSessionDuration.isFinite, maximumGestureSessionDuration > 0 else {
        throw ValidationError.invalidMaximumGestureSessionDuration
      }
    }
    guard maximumRawPointCount > 0 else {
      throw ValidationError.invalidMaximumRawPointCount
    }
    for (index, delay) in eventSourceStartRetryDelays.enumerated() {
      guard delay.isFinite, delay >= 0 else {
        throw ValidationError.invalidEventSourceStartRetryDelay(index: index)
      }
    }

    return Self(
      minimumGestureStartAxisDistance: minimumGestureStartAxisDistance,
      minimumDirectionChangeAxisDistance: minimumDirectionChangeAxisDistance,
      maximumGestureSessionDuration: maximumGestureSessionDuration,
      maximumRawPointCount: maximumRawPointCount,
      eventSourceStartRetryDelays: eventSourceStartRetryDelays
    )
  }

  private init(
    minimumGestureStartAxisDistance: Double,
    minimumDirectionChangeAxisDistance: Double,
    maximumGestureSessionDuration: TimeInterval?,
    maximumRawPointCount: Int,
    eventSourceStartRetryDelays: [TimeInterval]
  ) {
    self.minimumGestureStartAxisDistance = minimumGestureStartAxisDistance
    self.minimumDirectionChangeAxisDistance = minimumDirectionChangeAxisDistance
    self.maximumGestureSessionDuration = maximumGestureSessionDuration
    self.maximumRawPointCount = maximumRawPointCount
    self.eventSourceStartRetryDelays = eventSourceStartRetryDelays
  }
}
