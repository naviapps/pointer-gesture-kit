import Foundation

extension GestureRecognizer {
  func scheduleSessionExpirationIfNeeded(for sessionID: UUID) {
    guard let maximumGestureSessionDuration = tuning.maximumGestureSessionDuration else { return }

    sessionExpirationTask?.cancel()
    sessionExpirationTask = Task { [weak self] in
      do {
        try await Task.sleep(
          nanoseconds: GestureRecognizerTiming.sleepNanoseconds(
            for: maximumGestureSessionDuration))
      } catch {
        return
      }

      await MainActor.run {
        self?.expireSessionIfCurrent(sessionID)
      }
    }
  }

  @MainActor
  private func expireSessionIfCurrent(_ sessionID: UUID) {
    guard let activeSession = session, activeSession.sessionID == sessionID else { return }

    sessionExpirationTask = nil
    lastFailure = .gestureSessionExpired
    requestConsumedButtonInputReplayIfNeeded()
    resetGestureSession()
  }
}
