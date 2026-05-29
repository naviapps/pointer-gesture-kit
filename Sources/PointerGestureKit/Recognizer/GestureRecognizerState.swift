/// Combined observable state for a gesture recognizer.
public struct GestureRecognizerState: Hashable, Sendable {
  /// Observable recognizer status.
  public struct Status: Hashable, Sendable {
    /// Event-source lifecycle exposed by ``GestureRecognizer`` state.
    public enum Lifecycle: Hashable, Sendable {
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
    /// Directions recorded by the last completed gesture session.
    public let lastRecordedDirections: [GestureDirection]
    /// Last recognition failure.
    public let lastFailure: GestureRecognizerFailure?

    /// Creates observable recognizer status.
    ///
    /// Omitted values describe an idle recognizer with no active gesture session,
    /// recording mode disabled, no recorded directions, and no failure.
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
  public struct Trace: Hashable, Sendable {
    /// Whether the trace is visible.
    public let isVisible: Bool
    /// Raw gesture points currently shown by the trace.
    public let rawPoints: [GesturePoint]
    /// Gesture directions currently shown by the trace.
    public let directions: [GestureDirection]
    /// Normalized segment endpoints containing the trace start point plus one endpoint per direction.
    public let directionEndpoints: [GesturePoint]

    /// Creates observable trace state.
    ///
    /// Omitted values describe a hidden trace with no points or directions.
    public init(
      isVisible: Bool = false,
      rawPoints: [GesturePoint] = [],
      directions: [GestureDirection] = [],
      directionEndpoints: [GesturePoint] = []
    ) {
      self.isVisible = isVisible
      self.rawPoints = rawPoints
      self.directions = directions
      self.directionEndpoints = GestureTraceEndpointNormalizer.normalizedEndpoints(
        endpoints: directionEndpoints,
        recognizedDirectionCount: directions.count,
        publishedRawPoints: rawPoints
      )
    }
  }

  /// Status for event-source startup and recognition.
  public let status: Status
  /// Trace state for visual feedback.
  public let trace: Trace

  /// Creates combined observable recognizer state.
  ///
  /// Omitted values describe an idle recognizer with an empty trace.
  public init(status: Status = .init(), trace: Trace = .init()) {
    self.status = status
    self.trace = trace
  }
}
