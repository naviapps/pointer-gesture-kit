import Foundation

@MainActor
final class GestureRecognizerObservationCenter {
  private var snapshotObservers: [UUID: @MainActor @Sendable (GestureRecognizerState) -> Void] = [:]
  private var traceObservers: [UUID: GestureTraceObserver] = [:]
  private var snapshotNotificationTask: Task<Void, Never>?
  private var pendingSnapshotNotifications: [SnapshotNotification] = []
  private var pendingCurrentSnapshot: SnapshotNotification?

  func observeSnapshot(
    currentState: GestureRecognizerState,
    handler: @escaping @MainActor @Sendable (GestureRecognizerState) -> Void
  ) -> GestureObservationToken {
    let id = UUID()
    snapshotObservers[id] = handler
    handler(currentState)
    return GestureObservationToken { [weak self] in
      self?.snapshotObservers.removeValue(forKey: id)
    }
  }

  func observeTrace(
    currentTrace: GestureRecognizerState.Trace,
    handler: @escaping @MainActor @Sendable (GestureRecognizerState.Trace) -> Void
  ) -> GestureObservationToken {
    let id = UUID()
    let observer = GestureTraceObserver(handler: handler)
    observer.deliver(currentTrace)
    traceObservers[id] = observer
    return GestureObservationToken { [weak self] in
      self?.traceObservers.removeValue(forKey: id)
    }
  }

  func scheduleCurrentSnapshot(_ state: GestureRecognizerState) {
    let observerIDs = Set(snapshotObservers.keys)
    guard !observerIDs.isEmpty else { return }
    pendingCurrentSnapshot = SnapshotNotification(state: state, observerIDs: observerIDs)
    scheduleFlushIfNeeded()
  }

  func enqueueSnapshot(_ state: GestureRecognizerState) {
    guard !snapshotObservers.isEmpty else { return }
    pendingSnapshotNotifications.append(
      SnapshotNotification(state: state, observerIDs: Set(snapshotObservers.keys))
    )
    scheduleFlushIfNeeded()
  }

  func discardPendingVisibleTraceSnapshots() {
    pendingSnapshotNotifications.removeAll { $0.state.trace.isVisible }
  }

  func deliverTrace(
    _ trace: GestureRecognizerState.Trace,
    where shouldDeliver: (GestureTraceObserver) -> Bool
  ) {
    for observer in Array(traceObservers.values) where shouldDeliver(observer) {
      observer.deliver(trace)
    }
  }

  private func scheduleFlushIfNeeded() {
    guard snapshotNotificationTask == nil else { return }
    snapshotNotificationTask = Task { @MainActor [weak self] in
      guard !Task.isCancelled else { return }
      self?.flush()
    }
  }

  private func flush() {
    snapshotNotificationTask = nil
    var notifications = pendingSnapshotNotifications
    pendingSnapshotNotifications.removeAll()
    if let pendingCurrentSnapshot,
      notifications.last?.state != pendingCurrentSnapshot.state
    {
      notifications.append(pendingCurrentSnapshot)
    }
    self.pendingCurrentSnapshot = nil

    for notification in coalesced(notifications) {
      for observer in notification.observerIDs.compactMap({ snapshotObservers[$0] }) {
        observer(notification.state)
      }
    }
  }

  private func coalesced(_ notifications: [SnapshotNotification]) -> [SnapshotNotification] {
    var result: [SnapshotNotification] = []
    for notification in notifications {
      if notification.state.trace.isVisible,
        let previous = result.last,
        previous.state.trace.isVisible,
        previous.observerIDs == notification.observerIDs
      {
        result[result.index(before: result.endIndex)] = notification
      } else {
        result.append(notification)
      }
    }
    return result
  }
}

private struct SnapshotNotification {
  let state: GestureRecognizerState
  let observerIDs: Set<UUID>
}

@MainActor
final class GestureTraceObserver {
  private var lastTrace: GestureRecognizerState.Trace?
  private let handler: @MainActor @Sendable (GestureRecognizerState.Trace) -> Void

  init(handler: @escaping @MainActor @Sendable (GestureRecognizerState.Trace) -> Void) {
    self.handler = handler
  }

  var hasDeliveredVisibleTrace: Bool {
    lastTrace?.isVisible == true
  }

  func deliver(_ trace: GestureRecognizerState.Trace) {
    guard lastTrace != trace else { return }
    lastTrace = trace
    handler(trace)
  }
}
