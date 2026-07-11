extension GestureRecognizer {
  /// Current recognizer state snapshot.
  public var snapshot: GestureRecognizerState {
    GestureRecognizerState(status: currentStatus, trace: currentTrace)
  }

  private var currentStatus: GestureRecognizerState.Status {
    GestureRecognizerState.Status(
      lifecycle: currentLifecycle,
      isCapturingGesture: isCapturingGesture,
      isRecordingModeEnabled: isRecordingModeEnabled,
      lastRecordedDirections: lastRecordedDirections,
      lastFailure: lastFailure
    )
  }

  private var currentLifecycle: GestureRecognizerState.Status.Lifecycle {
    switch lifecycleState {
    case .idle: .idle
    case .starting: .starting
    case .ready: .ready
    case .retrying: .retrying
    case .failed: .failed
    }
  }

  private var currentTrace: GestureRecognizerState.Trace {
    GestureRecognizerState.Trace(
      isVisible: traceIsVisible,
      rawPoints: traceRawPoints,
      directions: traceDirections,
      directionEndpoints: traceDirectionEndpoints,
      tailPoint: traceTailPoint
    )
  }

  /// Observes combined recognizer state changes.
  @discardableResult
  public func observe(
    _ handler: @escaping @MainActor @Sendable (GestureRecognizerState) -> Void
  ) -> GestureObservationToken {
    observationCenter.observeSnapshot(currentState: snapshot, handler: handler)
  }

  /// Observes the status portion of the recognizer snapshot.
  @discardableResult
  public func observeStatus(
    _ handler: @escaping @MainActor @Sendable (GestureRecognizerState.Status) -> Void
  ) -> GestureObservationToken {
    let observer = DistinctStateObserver<GestureRecognizerState.Status>()
    return observe { state in
      observer.deliver(state.status, to: handler)
    }
  }

  /// Observes the trace portion of the recognizer snapshot with immediate live-trace delivery.
  @discardableResult
  public func observeTrace(
    _ handler: @escaping @MainActor @Sendable (GestureRecognizerState.Trace) -> Void
  ) -> GestureObservationToken {
    observationCenter.observeTrace(currentTrace: currentTrace, handler: handler)
  }

  func scheduleSnapshotNotificationIfChanged<Value: Equatable>(
    from oldValue: Value,
    to newValue: Value
  ) {
    guard !suppressSnapshotNotifications, oldValue != newValue else { return }
    observationCenter.scheduleCurrentSnapshot(snapshot)
  }

  func discardPendingVisibleTraceNotifications() {
    observationCenter.discardPendingVisibleTraceSnapshots()
  }

  func updatePublishedState(
    from session: GestureSession,
    publishRawPoints: Bool,
    notifyTrace: Bool? = nil
  ) {
    let previousTrace = currentTrace
    let wasVisible = traceIsVisible
    let shouldDeliverInitialVisibleTrace =
      !wasVisible && session.trace.isVisible
      && shouldPublishInitialVisibleTraceImmediately(for: session)
    let shouldDeliverTrace = notifyTrace ?? (publishRawPoints || traceRawPoints.isEmpty)
    let publishedRawPoints = publishRawPoints ? session.trace.rawPoints : traceRawPoints

    suppressSnapshotNotifications = !shouldDeliverTrace
    traceRawPoints = publishedRawPoints
    traceDirectionEndpoints = session.trace.directionEndpoints
    traceDirections = session.trace.directions
    traceTailPoint = session.trace.isVisible ? session.trace.tailPoint : nil
    suppressSnapshotNotifications = false

    traceIsVisible = session.trace.isVisible
    isCapturingGesture = session.recognition.isCapturingGesture

    if !wasVisible && traceIsVisible {
      observationCenter.enqueueSnapshot(snapshot)
    }
    deliverTraceIfNeeded(
      from: previousTrace,
      to: currentTrace,
      shouldDeliverTrace: shouldDeliverTrace,
      shouldDeliverInitialVisibleTrace: shouldDeliverInitialVisibleTrace
    )
  }

  func clearPublishedState(discardPendingVisibleTraceNotifications: Bool = false) {
    let previousTrace = currentTrace
    let wasVisible = traceIsVisible
    if discardPendingVisibleTraceNotifications {
      observationCenter.discardPendingVisibleTraceSnapshots()
    }

    traceRawPoints = []
    traceDirections = []
    traceDirectionEndpoints = []
    traceTailPoint = nil
    traceIsVisible = false
    isCapturingGesture = false

    if wasVisible {
      observationCenter.enqueueSnapshot(snapshot)
    }
    deliverTraceIfNeeded(
      from: previousTrace,
      to: currentTrace,
      shouldDeliverTrace: true,
      shouldDeliverInitialVisibleTrace: false
    )
  }

  private func deliverTraceIfNeeded(
    from previousTrace: GestureRecognizerState.Trace,
    to nextTrace: GestureRecognizerState.Trace,
    shouldDeliverTrace: Bool,
    shouldDeliverInitialVisibleTrace: Bool
  ) {
    guard previousTrace != nextTrace else { return }
    guard shouldDeliverTrace || previousTrace.isVisible != nextTrace.isVisible else { return }

    if shouldDeliverInitialVisibleTrace {
      observationCenter.deliverTrace(nextTrace) { _ in true }
    } else if previousTrace.isVisible {
      observationCenter.deliverTrace(nextTrace) { $0.hasDeliveredVisibleTrace }
    }
  }
}

@MainActor
private final class DistinctStateObserver<Value: Equatable & Sendable> {
  private var lastValue: Value?

  func deliver(_ value: Value, to handler: @MainActor @Sendable (Value) -> Void) {
    guard lastValue != value else { return }
    lastValue = value
    handler(value)
  }
}
