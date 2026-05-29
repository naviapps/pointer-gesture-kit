import Foundation

extension GestureRecognizer {
  /// Current recognizer state snapshot.
  public var snapshot: GestureRecognizerState {
    GestureRecognizerState(
      status: currentStatus,
      trace: currentTrace
    )
  }

  private var currentStatus: GestureRecognizerState.Status {
    GestureRecognizerState.Status(
      lifecycle: publicLifecycleState(for: lifecycleState),
      isCapturingGesture: isCapturingGesture,
      isRecordingModeEnabled: isRecordingModeEnabled,
      lastRecordedDirections: lastRecordedDirections,
      lastFailure: lastFailure
    )
  }

  private var currentTrace: GestureRecognizerState.Trace {
    GestureRecognizerState.Trace(
      isVisible: traceIsVisible,
      rawPoints: traceRawPoints,
      directions: traceDirections,
      directionEndpoints: traceDirectionEndpoints
    )
  }

  /// Observes combined recognizer state changes.
  @discardableResult
  public func observe(_ handler: @escaping @MainActor @Sendable (GestureRecognizerState) -> Void)
    -> GestureObservationToken
  {
    let id = UUID()
    snapshotObservers[id] = handler
    handler(snapshot)

    return GestureObservationToken(onCancel: { [weak self] in
      self?.snapshotObservers.removeValue(forKey: id)
    })
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

  /// Observes the trace portion of the recognizer snapshot.
  @discardableResult
  public func observeTrace(
    _ handler: @escaping @MainActor @Sendable (GestureRecognizerState.Trace) -> Void
  ) -> GestureObservationToken {
    let observer = DistinctStateObserver<GestureRecognizerState.Trace>()
    return observe { state in
      observer.deliver(state.trace, to: handler)
    }
  }

  private func scheduleSnapshotNotification() {
    guard !snapshotObservers.isEmpty else { return }
    guard snapshotNotificationTask == nil else { return }

    snapshotNotificationTask = Task { @MainActor [weak self] in
      await Task.yield()
      guard !Task.isCancelled else { return }
      guard let self else { return }

      snapshotNotificationTask = nil
      let current = snapshot
      let observers = Array(snapshotObservers.values)
      for observer in observers {
        observer(current)
      }
    }
  }

  func scheduleSnapshotNotificationIfChanged<Value: Equatable>(
    from oldValue: Value,
    to newValue: Value
  ) {
    guard oldValue != newValue else { return }
    scheduleSnapshotNotification()
  }

  func cancelSnapshotNotification() {
    snapshotNotificationTask?.cancel()
    snapshotNotificationTask = nil
  }

  func updatePublishedState(from session: GestureSession, publishRawPoints: Bool) {
    var publishedRawPoints: [GesturePoint]
    if publishRawPoints {
      publishedRawPoints = session.trace.rawPoints
      traceRawPoints = publishedRawPoints
    } else if !traceRawPoints.isEmpty {
      publishedRawPoints = traceRawPoints
    } else {
      publishedRawPoints = session.trace.rawPoints
      traceRawPoints = publishedRawPoints
    }

    traceDirectionEndpoints = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: session.trace.directionEndpoints,
      recognizedDirectionCount: session.trace.directions.count,
      publishedRawPoints: publishedRawPoints
    )
    traceDirections = session.trace.directions
    traceIsVisible = session.trace.isVisible
    isCapturingGesture = session.recognition.isCapturingGesture
  }

  func clearPublishedState() {
    traceRawPoints = []
    traceDirections = []
    traceDirectionEndpoints = []
    traceIsVisible = false
    isCapturingGesture = false
  }
}

private func publicLifecycleState<Match: Sendable>(
  for lifecycleState: GestureRecognizer<Match>.LifecycleState
) -> GestureRecognizerState.Status.Lifecycle {
  switch lifecycleState {
  case .idle:
    return .idle
  case .starting:
    return .starting
  case .ready:
    return .ready
  case .retrying:
    return .retrying
  case .failed:
    return .failed
  }
}

@MainActor
private final class DistinctStateObserver<Value: Equatable & Sendable> {
  private var lastValue: Value?

  func deliver(_ value: Value, to handler: @MainActor @Sendable (Value) -> Void) {
    if let lastValue, lastValue == value {
      return
    }
    lastValue = value
    handler(value)
  }
}
