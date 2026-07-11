import Foundation

extension GestureRecognizer {
  struct GestureSessionOutcome {
    let replayRequest: GestureReplayRequest
    let match: Match?
  }

  func beginGestureSession(
    at point: GesturePoint,
    consumedPoints: [GesturePoint],
    matcherCursor: GesturePatternMatcher<Match>?,
    isRecordingSession: Bool
  ) {
    let sessionID = UUID()
    let newSession = GestureSession(
      sessionID: sessionID,
      startPoint: point,
      trace: GestureSessionTraceState(
        rawPoints: [point],
        publishedRawPointCount: 1,
        directionEndpoints: [point],
        directions: [],
        tailPoint: point,
        isVisible: false
      ),
      recognition: GestureSessionRecognitionState(
        matcherCursor: isRecordingSession ? nil : matcherCursor,
        isRecordingSession: isRecordingSession,
        isCapturingGesture: true
      ),
      consumedButtonInput: ConsumedButtonInputState(
        points: consumedPoints.isEmpty ? [point] : consumedPoints,
        fallbackReplayPoint: nil,
        isConsumingInput: false
      )
    )
    session = newSession
    updatePublishedState(from: newSession, publishRawPoints: true)
    scheduleSessionExpirationIfNeeded(forSessionID: sessionID)
  }

  func updateGestureSession(
    to next: GesturePoint,
    publishRawPointsImmediately: Bool = false
  ) {
    guard isReady, var currentSession = session else { return }

    appendConsumedButtonPoint(next, to: &currentSession)

    if updateFallbackReplayPointIfGestureStopped(&currentSession, to: next) {
      session = currentSession
      return
    }

    guard let lastDirectionEndpoint = currentSession.trace.directionEndpoints.last else { return }

    currentSession.trace.rawPoints.append(next)
    currentSession.trace.tailPoint = next
    trimRawPointBuffer(&currentSession)

    let hasReachedStartDistance = hasReachedTraceStartDistance(for: currentSession, next: next)

    let previousDirectionCount = currentSession.trace.directions.count
    let didUpdateTraceGeometry = advanceGestureSession(
      for: &currentSession,
      next: next,
      lastDirectionEndpoint: lastDirectionEndpoint
    )
    let didAppendDirection = currentSession.trace.directions.count > previousDirectionCount
    currentSession.trace.isVisible = shouldRevealTrace(
      for: currentSession,
      hasReachedStartDistance: hasReachedStartDistance
    )

    let stoppedCapturingGesture = !currentSession.recognition.isCapturingGesture
    let shouldPublishTailPoint = currentSession.trace.isVisible
    let publishRawPoints =
      publishRawPointsImmediately || shouldPublishRawPointBatch(in: currentSession)
      || didAppendDirection || stoppedCapturingGesture
    if publishRawPoints {
      currentSession.trace.publishedRawPointCount = currentSession.trace.rawPoints.count
    }

    session = currentSession
    updatePublishedState(
      from: currentSession,
      publishRawPoints: publishRawPoints,
      notifyTrace: publishRawPoints || didUpdateTraceGeometry || shouldPublishTailPoint
    )
  }

  func completeGestureSession(
    at finalPoint: GesturePoint
  ) -> GestureSessionOutcome {
    guard isReady else {
      resetGestureSession()
      return clickOutcome(at: finalPoint)
    }

    guard let activeSession = session else {
      resetGestureSession()
      return clickOutcome(at: finalPoint)
    }

    defer {
      resetGestureSession()
    }

    if shouldReplayStoppedConsumedButtonInput(for: activeSession) {
      var stoppedSession = activeSession
      appendConsumedButtonPoint(finalPoint, to: &stoppedSession)
      let points = stoppedSession.consumedButtonInput.points
      return consumedButtonReplayOutcome(
        points: points,
        clickAt: consumedButtonClickReplayPoint(for: stoppedSession)
      )
    }

    updateGestureSession(to: finalPoint, publishRawPointsImmediately: true)

    guard var currentSession = session else {
      return clickOutcome(at: finalPoint)
    }

    let match = finalizeRecognition(in: &currentSession)

    lastRecordedDirections = currentSession.trace.directions

    session = currentSession
    updatePublishedState(from: currentSession, publishRawPoints: false)

    if let fallbackReplayPoint = currentSession.consumedButtonInput.fallbackReplayPoint {
      let points = currentSession.consumedButtonInput.points
      return consumedButtonReplayOutcome(
        points: points,
        clickAt: fallbackReplayPoint,
        match: match
      )
    }

    if currentSession.recognition.isRecordingSession {
      let points = currentSession.consumedButtonInput.points
      return consumedButtonReplayOutcome(
        points: points,
        clickAt: currentSession.startPoint,
        match: match
      )
    }

    return releaseOutcome(at: finalPoint, match: match)
  }

  func resetGestureSession(discardPendingVisibleTraceNotifications: Bool = false) {
    pendingButtonInput = nil
    session = nil
    clearPublishedState(
      discardPendingVisibleTraceNotifications: discardPendingVisibleTraceNotifications)
    inputExpirationTask?.cancel()
    inputExpirationTask = nil
  }

  func cancelGestureSession() {
    requestInterruptedButtonInputReplayIfNeeded()
    resetGestureSession(discardPendingVisibleTraceNotifications: true)
    lastFailure = nil
  }

  private func finalizeRecognition(in session: inout GestureSession) -> Match? {
    session.recognition.isCapturingGesture = false

    if session.trace.directions.isEmpty {
      ensureFallbackReplayPoint(in: &session)
      return nil
    }

    if let terminalMatch = session.recognition.matcherCursor?.completedMatch() {
      session.consumedButtonInput.fallbackReplayPoint = nil
      return terminalMatch
    }

    if !session.recognition.isRecordingSession {
      ensureFallbackReplayPoint(in: &session)
    }

    return nil
  }

  private func clickOutcome(
    at point: GesturePoint,
    match: Match? = nil
  ) -> GestureSessionOutcome {
    GestureSessionOutcome(
      replayRequest: .click(button: configuration.recognitionButton, at: point),
      match: match
    )
  }

  private func releaseOutcome(
    at point: GesturePoint,
    match: Match? = nil
  ) -> GestureSessionOutcome {
    GestureSessionOutcome(
      replayRequest: .release(button: configuration.recognitionButton, at: point),
      match: match
    )
  }

  private func consumedButtonReplayOutcome(
    points: [GesturePoint],
    clickAt point: GesturePoint,
    match: Match? = nil
  ) -> GestureSessionOutcome {
    GestureSessionOutcome(
      replayRequest: Self.consumedButtonReplayRequest(
        button: configuration.recognitionButton,
        points: points,
        clickAt: point
      ),
      match: match
    )
  }

  private func shouldReplayStoppedConsumedButtonInput(for session: GestureSession) -> Bool {
    !session.trace.isVisible && !session.recognition.isCapturingGesture
  }

  private func consumedButtonClickReplayPoint(for session: GestureSession) -> GesturePoint {
    session.consumedButtonInput.fallbackReplayPoint ?? session.startPoint
  }
}
