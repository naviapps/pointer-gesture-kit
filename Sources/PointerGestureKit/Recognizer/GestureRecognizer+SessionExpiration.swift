import Foundation

extension GestureRecognizer {
  private enum ExpirationTarget {
    case pending(UUID)
    case session(UUID)
  }

  /// Check during input delivery as well as from the timer: the main actor may not have
  /// resumed the sleeping task before a queued move or release arrives.
  func expireInputIfNeeded() {
    if let pendingButtonInput,
      pendingButtonInput.timing.remainingDuration(tuning: tuning) == 0
    {
      expirePendingButtonInputIfCurrentInputID(pendingButtonInput.inputID)
    }
    if let session, session.timing.remainingDuration(tuning: tuning) == 0 {
      expireSessionIfCurrentSessionID(session.sessionID)
    }
  }

  func schedulePendingButtonInputExpirationIfNeeded(forInputID inputID: UUID) {
    scheduleInputExpiration(for: .pending(inputID))
  }

  func scheduleSessionExpirationIfNeeded(forSessionID sessionID: UUID) {
    scheduleInputExpiration(for: .session(sessionID))
  }

  private func scheduleInputExpiration(for target: ExpirationTarget) {
    inputExpirationTask?.cancel()
    inputExpirationTask = nil
    guard remainingDuration(for: target) != nil else { return }

    inputExpirationTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        guard let remaining = self?.remainingDuration(for: target) else { return }
        if remaining <= 0 {
          switch target {
          case let .pending(id): self?.expirePendingButtonInputIfCurrentInputID(id)
          case let .session(id): self?.expireSessionIfCurrentSessionID(id)
          }
          return
        }
        do {
          try await Task.sleep(
            nanoseconds: GestureRecognizerTiming.taskSleepNanoseconds(for: remaining))
        } catch {
          return
        }
      }
    }
  }

  private func remainingDuration(for target: ExpirationTarget) -> TimeInterval? {
    switch target {
    case let .pending(id):
      guard let pendingButtonInput, pendingButtonInput.inputID == id else { return nil }
      return pendingButtonInput.timing.remainingDuration(tuning: tuning)
    case let .session(id):
      guard let session, session.sessionID == id else { return nil }
      return session.timing.remainingDuration(tuning: tuning)
    }
  }

  @MainActor
  private func expirePendingButtonInputIfCurrentInputID(_ inputID: UUID) {
    guard let pendingButtonInput, pendingButtonInput.inputID == inputID else { return }

    inputExpirationTask?.cancel()
    inputExpirationTask = nil
    lastFailure = .gestureSessionExpired
    requestInterruptedButtonInputReplayIfNeeded()
    self.pendingButtonInput = nil
    clearPublishedState(discardPendingVisibleTraceNotifications: true)
  }

  @MainActor
  private func expireSessionIfCurrentSessionID(_ sessionID: UUID) {
    guard let activeSession = session, activeSession.sessionID == sessionID else { return }

    inputExpirationTask?.cancel()
    inputExpirationTask = nil
    lastFailure = .gestureSessionExpired
    requestInterruptedButtonInputReplayIfNeeded()
    resetGestureSession(discardPendingVisibleTraceNotifications: true)
  }
}
