extension GestureRecognizer {
  private static var rawPointPublishBatchSize: Int { 10 }

  func trimBuffer(_ session: inout GestureSession) {
    let overflow = session.trace.rawPoints.count - tuning.maximumRawPointCount
    guard overflow > 0 else { return }
    session.trace.rawPoints.removeFirst(overflow)
    session.trace.publishedRawPointCount = max(0, session.trace.publishedRawPointCount - overflow)
  }

  func shouldPublishRawPoints(in session: GestureSession) -> Bool {
    (session.trace.rawPoints.count - session.trace.publishedRawPointCount)
      >= Self.rawPointPublishBatchSize
  }

  func shouldShowTrace(for session: GestureSession, next: GesturePoint) -> Bool {
    let movementThreshold = tuning.minimumGestureStartAxisDistance
    return GestureMovementResolver.maximumAxisDelta(from: session.startPoint, to: next)
      > movementThreshold
  }

  func updateDirectionState(
    for session: inout GestureSession,
    next: GesturePoint,
    lastDirectionEndpoint: GesturePoint
  ) -> Bool {
    guard
      let newDirection = GestureMovementResolver.dominantDirection(
        from: lastDirectionEndpoint,
        to: next
      )
    else {
      return false
    }

    if let lastDirection = session.trace.directions.last, lastDirection == newDirection {
      session.trace.directionEndpoints[session.trace.directionEndpoints.count - 1] = next
      return false
    }

    if !session.trace.directions.isEmpty {
      let directionThreshold = tuning.minimumDirectionChangeAxisDistance
      guard
        GestureMovementResolver.maximumAxisDelta(from: lastDirectionEndpoint, to: next)
          > directionThreshold
      else {
        return false
      }
    }

    if isRecordingModeEnabled {
      session.trace.directions.append(newDirection)
      session.trace.directionEndpoints.append(next)
      return true
    }

    session.recognition.matcherCursor =
      session.recognition.matcherCursor?.advanced(to: newDirection)

    guard session.recognition.matcherCursor != nil else {
      session.recognition.isCapturingGesture = false
      session.trace.isVisible = false
      session.recognition.matcherCursor = nil
      ensureFallbackReplayPoint(in: &session)
      return false
    }

    session.trace.directions.append(newDirection)
    session.trace.directionEndpoints.append(next)
    return true
  }
}
