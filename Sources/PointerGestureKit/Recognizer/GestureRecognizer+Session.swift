import Foundation

extension GestureRecognizer {
  struct GestureSessionOutcome {
    let replayRequest: GestureReplayRequest
    let match: Match?
  }

  func beginGestureSession(
    at point: GesturePoint,
    consumedPoints: [GesturePoint],
    context: GestureRecognitionContext?
  ) {
    lastRecordedDirections = []
    let sessionID = UUID()
    let newSession = GestureSession(
      sessionID: sessionID,
      startPoint: point,
      trace: GestureSessionTraceState(
        rawPoints: [point],
        publishedRawPointCount: 1,
        directionEndpoints: [point],
        directions: [],
        isVisible: false
      ),
      recognition: GestureSessionRecognitionState(
        matcherCursor: makeMatcher(context),
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
    scheduleSessionExpirationIfNeeded(for: sessionID)
  }

  func updateGestureSession(
    to next: GesturePoint,
    forcePublish: Bool = false
  ) {
    guard isReady, var currentSession = session else { return }

    appendConsumedButtonPoint(next, to: &currentSession)

    if updateFallbackReplayPointIfGestureStopped(&currentSession, to: next) {
      session = currentSession
      return
    }

    guard let lastDirectionEndpoint = currentSession.trace.directionEndpoints.last else { return }

    currentSession.trace.rawPoints.append(next)
    trimBuffer(&currentSession)

    currentSession.trace.isVisible =
      currentSession.trace.isVisible || shouldShowTrace(for: currentSession, next: next)

    let didAcceptNewDirection = updateDirectionState(
      for: &currentSession,
      next: next,
      lastDirectionEndpoint: lastDirectionEndpoint
    )

    let publishRawPoints =
      forcePublish || shouldPublishRawPoints(in: currentSession) || didAcceptNewDirection
    if publishRawPoints {
      currentSession.trace.publishedRawPointCount = currentSession.trace.rawPoints.count
    }

    session = currentSession
    updatePublishedState(from: currentSession, publishRawPoints: publishRawPoints)
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
      return replayedConsumedButtonInputOutcome(
        points: points,
        clickAt: consumedButtonClickReplayPoint(for: stoppedSession)
      )
    }

    updateGestureSession(to: finalPoint, forcePublish: true)

    guard var currentSession = session else {
      return clickOutcome(at: finalPoint)
    }

    let match = finalizeRecognition(in: &currentSession)

    lastRecordedDirections = currentSession.trace.directions

    session = currentSession
    updatePublishedState(from: currentSession, publishRawPoints: false)

    if let fallbackReplayPoint = currentSession.consumedButtonInput.fallbackReplayPoint {
      let points = currentSession.consumedButtonInput.points
      return replayedConsumedButtonInputOutcome(
        points: points,
        clickAt: fallbackReplayPoint,
        match: match
      )
    }

    if isRecordingModeEnabled {
      let points = currentSession.consumedButtonInput.points
      return replayedConsumedButtonInputOutcome(
        points: points,
        clickAt: currentSession.startPoint,
        match: match
      )
    }

    return releaseOutcome(at: finalPoint, match: match)
  }

  func resetGestureSession() {
    pendingButtonInput = nil
    session = nil
    clearPublishedState()
    sessionExpirationTask?.cancel()
    sessionExpirationTask = nil
  }

  func cancelGestureSession() {
    requestConsumedButtonInputReplayIfNeeded()
    resetGestureSession()
    lastFailure = nil
  }

  private func finalizeRecognition(in session: inout GestureSession) -> Match? {
    session.recognition.isCapturingGesture = false

    if session.trace.directions.isEmpty {
      ensureFallbackReplayPoint(in: &session)
      return nil
    }

    if let currentMatch = session.recognition.matcherCursor?.currentMatch {
      session.consumedButtonInput.fallbackReplayPoint = nil
      return currentMatch
    }

    if !isRecordingModeEnabled {
      ensureFallbackReplayPoint(in: &session)
    }

    return nil
  }

  private func clickOutcome(
    at point: GesturePoint,
    match: Match? = nil
  ) -> GestureSessionOutcome {
    GestureSessionOutcome(replayRequest: .click(button: recognitionButton, at: point), match: match)
  }

  private func releaseOutcome(
    at point: GesturePoint,
    match: Match? = nil
  ) -> GestureSessionOutcome {
    GestureSessionOutcome(
      replayRequest: .release(button: recognitionButton, at: point),
      match: match
    )
  }

  private func replayedConsumedButtonInputOutcome(
    points: [GesturePoint],
    clickAt point: GesturePoint,
    match: Match? = nil
  ) -> GestureSessionOutcome {
    GestureSessionOutcome(
      replayRequest: .consumedButtonInput(
        button: recognitionButton,
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
