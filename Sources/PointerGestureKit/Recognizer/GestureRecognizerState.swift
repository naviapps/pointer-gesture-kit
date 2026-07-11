/// Combined observable state for a gesture recognizer.
public struct GestureRecognizerState: Equatable, Sendable {
  /// Observable recognizer status.
  public struct Status: Equatable, Sendable {
    /// Event-source lifecycle exposed by ``GestureRecognizer`` state.
    public enum Lifecycle: Equatable, Sendable {
      /// The recognizer is stopped.
      case idle

      /// The recognizer is starting its event source.
      case starting

      /// The recognizer is ready to receive gesture input.
      case ready

      /// The recognizer is waiting to retry event-source startup.
      case retrying

      /// The recognizer failed to start and has no scheduled retry.
      case failed
    }

    /// Event-source lifecycle.
    public let lifecycle: Lifecycle
    /// Whether an active gesture session is currently capturing directions.
    public let isCapturingGesture: Bool
    /// Whether recording mode is enabled.
    public let isRecordingModeEnabled: Bool
    /// Directions recorded by the last completed gesture session, including recording-mode
    /// captures.
    public let lastRecordedDirections: [GestureDirection]
    /// Last startup, enablement-policy, modifier-policy, or input-expiration failure.
    public let lastFailure: GestureRecognizerFailure?

    /// Creates observable recognizer status.
    public init(
      lifecycle: Lifecycle = .idle,
      isCapturingGesture: Bool = false,
      isRecordingModeEnabled: Bool = false,
      lastRecordedDirections: [GestureDirection] = [],
      lastFailure: GestureRecognizerFailure? = nil
    ) {
      self.lifecycle = lifecycle
      self.isCapturingGesture = isCapturingGesture
      self.isRecordingModeEnabled = isRecordingModeEnabled
      self.lastRecordedDirections = lastRecordedDirections
      self.lastFailure = lastFailure
    }
  }

  /// Observable trace state for a gesture recognizer.
  public struct Trace: Equatable, Sendable {
    /// Whether the trace is visible after recording feedback or a valid matcher prefix.
    public let isVisible: Bool
    /// Published raw gesture point history.
    public let rawPoints: [GesturePoint]
    /// Gesture directions currently shown by the trace.
    public let directions: [GestureDirection]
    /// Normalized segment endpoints containing the trace start point plus one endpoint per direction.
    public let directionEndpoints: [GesturePoint]
    /// Latest pointer point for low-latency live trace rendering.
    public let tailPoint: GesturePoint?

    /// Creates observable trace state.
    public init(
      isVisible: Bool = false,
      rawPoints: [GesturePoint] = [],
      directions: [GestureDirection] = [],
      directionEndpoints: [GesturePoint] = [],
      tailPoint: GesturePoint? = nil
    ) {
      self.isVisible = isVisible
      self.rawPoints = rawPoints
      self.directions = directions
      self.directionEndpoints = directionEndpoints
      self.tailPoint = tailPoint
    }
  }

  /// Status for event-source startup and recognition.
  public let status: Status
  /// Trace state for visual feedback.
  public let trace: Trace

  /// Creates combined observable recognizer state.
  public init(status: Status = .init(), trace: Trace = .init()) {
    self.status = status
    self.trace = trace
  }
}
