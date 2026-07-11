extension GestureRecognizer {
  func requestInterruptedButtonInputReplayIfNeeded() {
    guard
      let replayRequest = Self.interruptedButtonInputReplayRequest(
        session: session,
        pendingButtonInput: pendingButtonInput,
        recognitionButton: configuration.recognitionButton,
        minimumGestureStartAxisDistance: tuning.minimumGestureStartAxisDistance
      )
    else { return }

    configuration.onReplayRequested(replayRequest)
  }

  func requestConsumedButtonReplay(points: [GesturePoint], clickAt point: GesturePoint) {
    configuration.onReplayRequested(
      Self.consumedButtonReplayRequest(
        button: configuration.recognitionButton,
        points: points,
        clickAt: point
      ))
  }

  nonisolated static func interruptedButtonInputReplayRequest(
    session: GestureSession?,
    pendingButtonInput: PendingButtonInput?,
    recognitionButton: PointerButton,
    minimumGestureStartAxisDistance: Double
  ) -> GestureReplayRequest? {
    if let session {
      if let replayPoint = session.consumedButtonInput.fallbackReplayPoint {
        return consumedButtonReplayRequest(
          button: recognitionButton,
          points: session.consumedButtonInput.points,
          clickAt: replayPoint
        )
      }

      if session.recognition.isCapturingGesture {
        return .release(
          button: recognitionButton,
          at: interruptedReleasePoint(for: session)
        )
      }

      return nil
    }

    guard let pendingButtonInput else { return nil }
    return pendingButtonInputReplayRequest(
      pendingButtonInput,
      button: recognitionButton,
      minimumGestureStartAxisDistance: minimumGestureStartAxisDistance
    )
  }

  nonisolated static func pendingButtonInputReplayRequest(
    _ pendingButtonInput: PendingButtonInput,
    button: PointerButton,
    minimumGestureStartAxisDistance: Double
  ) -> GestureReplayRequest {
    guard
      shouldReplayPendingButtonInputAsDrag(
        pendingButtonInput,
        minimumGestureStartAxisDistance: minimumGestureStartAxisDistance
      )
    else {
      return .click(button: button, at: pendingButtonInput.startPoint)
    }

    return .drag(button: button, points: pendingButtonInput.consumedButtonPoints)
  }

  private nonisolated static func shouldReplayPendingButtonInputAsDrag(
    _ pendingButtonInput: PendingButtonInput,
    minimumGestureStartAxisDistance: Double
  ) -> Bool {
    guard pendingButtonInput.consumedButtonPoints.count > 1 else { return false }
    return pendingButtonInput.consumedButtonPoints.contains {
      GestureMovementResolver.maximumAbsoluteAxisDelta(
        from: pendingButtonInput.startPoint,
        to: $0
      ) >= minimumGestureStartAxisDistance
    }
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
      trimConsumedButtonPoints(&session.consumedButtonInput.points)
    }
  }

  func trimConsumedButtonPoints(_ points: inout [GesturePoint]) {
    let maximumPointCount = max(2, tuning.maximumRawPointCount)
    let overflow = points.count - maximumPointCount
    guard overflow > 0 else { return }
    points.removeSubrange(1..<(1 + overflow))
  }

  private nonisolated static func interruptedReleasePoint(for session: GestureSession)
    -> GesturePoint
  {
    session.consumedButtonInput.fallbackReplayPoint
      ?? session.trace.rawPoints.last
      ?? session.startPoint
  }
}
