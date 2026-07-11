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

  /// Whether the recognizer records directions without requiring modifier approval or a matcher.
  ///
  /// Recording mode still respects the configured recognition-enabled policy for the active
  /// context. Changes apply to gesture sessions that start after the value changes; an active
  /// session keeps the mode it started with.
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

  var traceTailPoint: GesturePoint? {
    didSet {
      scheduleSnapshotNotificationIfChanged(from: oldValue, to: traceTailPoint)
    }
  }

  // MARK: - Observation State

  let observationCenter = GestureRecognizerObservationCenter()
  var suppressSnapshotNotifications = false

  // MARK: - Runtime Configuration

  let eventSource: any GestureEventSource
  let configuration: GestureRecognizerConfiguration<Match>
  var tuning: GestureRecognizerTuning {
    didSet {
      refreshDeinitializationReplayRequest()
    }
  }

  // MARK: - Runtime State

  let cleanup: GestureRecognizerCleanup
  var session: GestureSession? {
    didSet {
      refreshDeinitializationReplayRequest()
    }
  }
  var startupRetryTask: Task<Void, Never>? {
    get { cleanup.startupRetryTask }
    set { cleanup.startupRetryTask = newValue }
  }
  var startRequested = false
  var inputExpirationTask: Task<Void, Never>? {
    get { cleanup.inputExpirationTask }
    set { cleanup.inputExpirationTask = newValue }
  }
  var pendingButtonInput: PendingButtonInput? {
    didSet {
      refreshDeinitializationReplayRequest()
    }
  }

  // MARK: - Initialization

  /// Creates a gesture recognizer from an event source and host-owned recognition configuration.
  public init(
    eventSource: any GestureEventSource,
    configuration: GestureRecognizerConfiguration<Match>
  ) {
    self.eventSource = eventSource
    self.configuration = configuration
    tuning = configuration.tuning
    cleanup = GestureRecognizerCleanup(
      eventSource: eventSource,
      onReplayRequested: configuration.onReplayRequested
    )
  }

  private func refreshDeinitializationReplayRequest() {
    cleanup.replayRequest = Self.interruptedButtonInputReplayRequest(
      session: session,
      pendingButtonInput: pendingButtonInput,
      recognitionButton: configuration.recognitionButton,
      minimumGestureStartAxisDistance: tuning.minimumGestureStartAxisDistance
    )
  }

  nonisolated static func consumedButtonReplayRequest(
    button: PointerButton,
    points: [GesturePoint],
    clickAt point: GesturePoint
  ) -> GestureReplayRequest {
    points.count > 1
      ? .drag(button: button, points: points)
      : .click(button: button, at: point)
  }

  /// Updates recognition thresholds, runtime limits, and startup retry tuning.
  ///
  /// Existing gesture-input expiration and startup retry work is rescheduled only when the value
  /// changes. The return value lets host apps avoid canceling active input for duplicate updates.
  @discardableResult
  public func updateTuning(_ tuning: GestureRecognizerTuning) -> Bool {
    guard self.tuning != tuning else { return false }

    self.tuning = tuning
    rescheduleInputExpirationAfterTuningUpdate()
    rescheduleStartupRetryAfterTuningUpdate()
    return true
  }

  private func rescheduleInputExpirationAfterTuningUpdate() {
    inputExpirationTask?.cancel()
    inputExpirationTask = nil

    if let session {
      scheduleSessionExpirationIfNeeded(forSessionID: session.sessionID)
      return
    }

    if let pendingButtonInput {
      schedulePendingButtonInputExpirationIfNeeded(forInputID: pendingButtonInput.inputID)
      return
    }
  }

  private func rescheduleStartupRetryAfterTuningUpdate() {
    guard startRequested, !isReady else { return }

    cancelStartupRetry()
    lifecycleState = tuning.eventSourceStartRetryDelays.isEmpty ? .failed : .retrying
    scheduleStartupRetry()
  }
}
