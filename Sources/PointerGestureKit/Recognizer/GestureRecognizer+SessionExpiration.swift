import Foundation

extension GestureRecognizer {
  func schedulePendingButtonInputExpirationIfNeeded(forInputID inputID: UUID) {
    guard let maximumGestureSessionDuration = tuning.maximumGestureSessionDuration else { return }

    inputExpirationTask?.cancel()
    inputExpirationTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(
          nanoseconds: GestureRecognizerTiming.taskSleepNanoseconds(
            for: maximumGestureSessionDuration))
      } catch {
        return
      }

      self?.expirePendingButtonInputIfCurrentInputID(inputID)
    }
  }

  func scheduleSessionExpirationIfNeeded(forSessionID sessionID: UUID) {
    guard let maximumGestureSessionDuration = tuning.maximumGestureSessionDuration else { return }

    inputExpirationTask?.cancel()
    inputExpirationTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(
          nanoseconds: GestureRecognizerTiming.taskSleepNanoseconds(
            for: maximumGestureSessionDuration))
      } catch {
        return
      }

      self?.expireSessionIfCurrentSessionID(sessionID)
    }
  }

  @MainActor
  private func expirePendingButtonInputIfCurrentInputID(_ inputID: UUID) {
    guard let pendingButtonInput, pendingButtonInput.inputID == inputID else { return }

    inputExpirationTask = nil
    lastFailure = .gestureSessionExpired
    requestInterruptedButtonInputReplayIfNeeded()
    self.pendingButtonInput = nil
    clearPublishedState(discardPendingVisibleTraceNotifications: true)
  }

  @MainActor
  private func expireSessionIfCurrentSessionID(_ sessionID: UUID) {
    guard let activeSession = session, activeSession.sessionID == sessionID else { return }

    inputExpirationTask = nil
    lastFailure = .gestureSessionExpired
    requestInterruptedButtonInputReplayIfNeeded()
    resetGestureSession(discardPendingVisibleTraceNotifications: true)
  }
}
