extension GestureRecognizer {
  private static var rawPointPublicationBatchSize: Int { 10 }

  func trimRawPointBuffer(_ session: inout GestureSession) {
    let overflow = session.trace.rawPoints.count - tuning.maximumRawPointCount
    guard overflow > 0 else { return }
    session.trace.rawPoints.removeFirst(overflow)
    session.trace.publishedRawPointCount = max(0, session.trace.publishedRawPointCount - overflow)
  }

  func shouldPublishRawPointBatch(in session: GestureSession) -> Bool {
    (session.trace.rawPoints.count - session.trace.publishedRawPointCount)
      >= Self.rawPointPublicationBatchSize
  }

  func hasReachedTraceStartDistance(for session: GestureSession, next: GesturePoint) -> Bool {
    let movementThreshold = tuning.minimumGestureStartAxisDistance
    return GestureMovementResolver.maximumAbsoluteAxisDelta(from: session.startPoint, to: next)
      >= movementThreshold
  }

  func shouldRevealTrace(
    for session: GestureSession,
    hasReachedStartDistance: Bool
  ) -> Bool {
    guard hasReachedStartDistance else { return false }
    guard !session.trace.directions.isEmpty else { return false }
    guard !session.recognition.isRecordingSession else { return true }
    return session.recognition.matcherCursor != nil
  }

  func shouldPublishInitialVisibleTraceImmediately(for session: GestureSession) -> Bool {
    guard session.trace.isVisible else { return false }
    guard !session.trace.directions.isEmpty else { return false }
    if session.recognition.isRecordingSession {
      return true
    }
    return session.recognition.matcherCursor != nil
  }

  func advanceGestureSession(
    for session: inout GestureSession,
    next: GesturePoint,
    lastDirectionEndpoint: GesturePoint
  ) -> Bool {
    guard
      let newDirection = GestureMovementResolver.dominantAxisDirection(
        from: lastDirectionEndpoint,
        to: next
      )
    else {
      return false
    }

    if let lastDirection = session.trace.directions.last, lastDirection == newDirection {
      session.trace.directionEndpoints[session.trace.directionEndpoints.count - 1] = next
      return true
    }

    if !session.trace.directions.isEmpty {
      let directionThreshold = tuning.minimumDirectionChangeAxisDistance
      guard
        GestureMovementResolver.maximumAbsoluteAxisDelta(from: lastDirectionEndpoint, to: next)
          >= directionThreshold
      else {
        return false
      }
    }

    if session.recognition.isRecordingSession {
      session.trace.directions.append(newDirection)
      session.trace.directionEndpoints.append(next)
      return true
    }

    guard let matcherCursor = session.recognition.matcherCursor?.advanced(to: newDirection) else {
      discardPendingVisibleTraceNotifications()
      session.recognition.isCapturingGesture = false
      session.recognition.matcherCursor = nil
      clearSessionTrace(&session)
      ensureFallbackReplayPoint(in: &session)
      return true
    }
    session.recognition.matcherCursor = matcherCursor

    session.trace.directions.append(newDirection)
    session.trace.directionEndpoints.append(next)
    return true
  }

  private func clearSessionTrace(_ session: inout GestureSession) {
    session.trace.rawPoints = []
    session.trace.publishedRawPointCount = 0
    session.trace.directionEndpoints = []
    session.trace.directions = []
    session.trace.tailPoint = nil
    session.trace.isVisible = false
  }
}
