import Foundation

/// Main-actor recognizer that coordinates event input, gesture matching, and observation.
///
/// Create the recognizer with an event source and a ``GestureRecognizerConfiguration`` that supplies
/// pattern matching, replay handling, match delivery, recognition policy, and runtime tuning.
@MainActor
public final class GestureRecognizer<Match: Sendable> {
  // MARK: - Published Status

  var lifecycleState: LifecycleState = .idle {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: lifecycleState)
    }
  }

  var isReady: Bool {
    lifecycleState == .ready
  }

  var isCapturingGesture = false {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: isCapturingGesture)
    }
  }

  /// Whether the recognizer records directions without requiring modifier approval or a match.
  public var isRecordingModeEnabled: Bool = false {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: isRecordingModeEnabled)
    }
  }

  var lastRecordedDirections: [GestureDirection] = [] {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: lastRecordedDirections)
    }
  }

  var lastFailure: GestureRecognizerFailure? {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: lastFailure)
    }
  }

  // MARK: - Published Trace

  var traceIsVisible = false {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: traceIsVisible)
    }
  }

  var traceDirections: [GestureDirection] = [] {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: traceDirections)
    }
  }

  var traceDirectionEndpoints: [GesturePoint] = [] {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: traceDirectionEndpoints)
    }
  }

  var traceRawPoints: [GesturePoint] = [] {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: traceRawPoints)
    }
  }

  // MARK: - Observation State

  var snapshotObservers: [UUID: @MainActor @Sendable (GestureRecognizerState) -> Void] = [:]
  var snapshotNotificationTask: Task<Void, Never>?

  // MARK: - Runtime Configuration

  let eventSource: any GestureEventSource
  let tuning: GestureRecognizerTuning

  // MARK: - Runtime State

  var session: GestureSession?
  var startupRetryTask: Task<Void, Never>?
  var startRequested = false
  var sessionExpirationTask: Task<Void, Never>?
  var pendingButtonInput: PendingButtonInput?

  // MARK: - Recognition Configuration

  let makeMatcher: @MainActor @Sendable (GestureRecognitionContext?) -> GesturePatternMatcher<Match>
  let recognitionButton: PointerButton
  let onReplayRequested: @MainActor @Sendable (GestureReplayRequest) -> Void
  let onMatch: @MainActor @Sendable (Match) -> Void
  let recognitionContext: @MainActor @Sendable (GesturePoint) -> GestureRecognitionContext?
  let isRecognitionEnabled: @MainActor @Sendable (GestureRecognitionContext?) -> Bool
  let areModifiersSatisfied:
    @MainActor @Sendable (
      GestureModifierFlags, GestureRecognitionContext?
    ) -> Bool

  // MARK: - Initialization

  /// Creates a gesture recognizer from an event source and host-owned recognition configuration.
  public init(
    eventSource: any GestureEventSource,
    configuration: GestureRecognizerConfiguration<Match>
  ) {
    self.eventSource = eventSource
    tuning = configuration.tuning
    makeMatcher = configuration.makeMatcher
    recognitionButton = configuration.recognitionButton
    onReplayRequested = configuration.onReplayRequested
    onMatch = configuration.onMatch
    recognitionContext = configuration.recognitionContext
    isRecognitionEnabled = configuration.isRecognitionEnabled
    areModifiersSatisfied = configuration.areModifiersSatisfied
  }

  isolated deinit {
    stopRuntimeResources()
    cancelSnapshotNotification()
  }
}
