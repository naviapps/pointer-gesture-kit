extension GestureRecognizer {
  func requestConsumedButtonInputReplayIfNeeded() {
    if let activeSession = session {
      if activeSession.recognition.isCapturingGesture {
        onReplayRequested(
          .release(button: recognitionButton, at: releasePoint(for: activeSession)))
      } else if let replayPoint = activeSession.consumedButtonInput.fallbackReplayPoint {
        requestConsumedButtonInputReplay(
          activeSession.consumedButtonInput.points,
          clickAt: replayPoint
        )
      }
      return
    }

    guard let pendingInput = pendingButtonInput else { return }

    requestConsumedButtonInputReplay(
      pendingInput.consumedButtonPoints,
      clickAt: pendingInput.startPoint
    )
  }

  func requestConsumedButtonInputReplay(_ points: [GesturePoint], clickAt point: GesturePoint) {
    onReplayRequested(
      .consumedButtonInput(button: recognitionButton, points: points, clickAt: point))
  }

  func ensureFallbackReplayPoint(in session: inout GestureSession) {
    session.consumedButtonInput.fallbackReplayPoint =
      session.consumedButtonInput.fallbackReplayPoint ?? session.startPoint
  }

  func updateFallbackReplayPointIfGestureStopped(
    _ session: inout GestureSession,
    to point: GesturePoint
  )
    -> Bool
  {
    guard session.recognition.isCapturingGesture else {
      session.consumedButtonInput.fallbackReplayPoint = point
      return true
    }
    return false
  }

  func appendConsumedButtonPoint(
    _ point: GesturePoint,
    to session: inout GestureSession
  ) {
    if session.consumedButtonInput.points.last != point {
      session.consumedButtonInput.points.append(point)
    }
  }

  private func releasePoint(for session: GestureSession) -> GesturePoint {
    session.consumedButtonInput.fallbackReplayPoint
      ?? session.trace.rawPoints.last
      ?? session.startPoint
  }
}
