import Foundation

extension GestureRecognizer {
  private var isTrackingButtonInput: Bool {
    pendingButtonInput != nil || session != nil
  }

  func handleInputEvent(_ event: GestureInputEvent) -> GestureEventDisposition {
    guard isReady, event.location.isFinite else { return .passThrough }

    switch event.kind {
    case let .buttonDown(button):
      guard button == configuration.recognitionButton else { return .passThrough }
      if isTrackingButtonInput {
        cancelGestureSession()
      }

      let policyResult = evaluateRecognitionPolicy(
        at: event.location,
        modifiers: event.modifiers
      )
      guard case let .allowed(recognitionContext) = policyResult else {
        return .passThrough
      }

      return beginButtonInput(
        at: event.location,
        recognitionContext: recognitionContext
      )

    case let .buttonMoved(button):
      guard button == configuration.recognitionButton else { return .passThrough }
      return continueButtonInput(at: event.location)

    case let .buttonUp(button):
      guard button == configuration.recognitionButton else { return .passThrough }
      return finishButtonInput(at: event.location)

    case .cancel:
      return cancelButtonInput()
    }
  }

  private func cancelButtonInput() -> GestureEventDisposition {
    guard isTrackingButtonInput else { return .passThrough }
    cancelGestureSession()
    return .consume
  }

  private func beginButtonInput(
    at location: GesturePoint,
    recognitionContext: GestureRecognitionContext?
  ) -> GestureEventDisposition {
    let isRecordingSession = isRecordingModeEnabled
    let matcherCursor = isRecordingSession ? nil : configuration.makeMatcher(recognitionContext)
    guard
      isRecordingSession || !configuration.passesThroughEmptyMatcher
        || matcherCursor?.isEmpty == false
    else {
      return .passThrough
    }

    let inputID = UUID()
    pendingButtonInput = PendingButtonInput(
      inputID: inputID,
      startPoint: location,
      consumedButtonPoints: [location],
      matcherCursor: matcherCursor,
      isRecordingSession: isRecordingSession
    )
    schedulePendingButtonInputExpirationIfNeeded(forInputID: inputID)
    return .consume
  }

  private func continueButtonInput(at location: GesturePoint)
    -> GestureEventDisposition
  {
    if session == nil {
      guard let pendingInput = pendingButtonInput else { return .passThrough }
      guard shouldPromotePendingButtonInputToGesture(from: pendingInput.startPoint, to: location)
      else {
        appendPendingButtonInputPoint(location)
        return .consume
      }

      beginGestureSession(
        at: pendingInput.startPoint,
        consumedPoints: pendingInput.consumedButtonPoints,
        matcherCursor: pendingInput.matcherCursor,
        isRecordingSession: pendingInput.isRecordingSession
      )
      pendingButtonInput = nil
    }

    updateGestureSession(to: location)
    if releaseStoppedButtonInputIfNeeded() {
      return .consume
    }

    guard var activeSession = session else { return .passThrough }
    if shouldConsumeButtonInput(for: activeSession) {
      activeSession.consumedButtonInput.isConsumingInput = true
      session = activeSession
      return .consume
    }

    return .passThrough
  }

  private func finishButtonInput(at location: GesturePoint) -> GestureEventDisposition {
    guard let activeSession = session else {
      if let pendingInput = pendingButtonInput, pendingInput.consumedButtonPoints.count > 1 {
        appendPendingButtonInputPoint(location)
      }
      return requestPendingButtonInputReplay()
    }

    if !activeSession.consumedButtonInput.isConsumingInput {
      resetGestureSession()
      return .passThrough
    }

    let outcome = completeGestureSession(at: location)
    configuration.onReplayRequested(outcome.replayRequest)
    if let match = outcome.match {
      configuration.onMatch(match)
    }
    return .consume
  }

  private func requestPendingButtonInputReplay() -> GestureEventDisposition {
    guard let pendingInput = pendingButtonInput else { return .passThrough }
    pendingButtonInput = nil
    inputExpirationTask?.cancel()
    inputExpirationTask = nil
    configuration.onReplayRequested(
      Self.pendingButtonInputReplayRequest(
        pendingInput,
        button: configuration.recognitionButton,
        minimumGestureStartAxisDistance: tuning.minimumGestureStartAxisDistance
      )
    )
    return .consume
  }

  private func appendPendingButtonInputPoint(_ point: GesturePoint) {
    guard var pendingInput = pendingButtonInput else { return }
    if pendingInput.consumedButtonPoints.last != point {
      pendingInput.consumedButtonPoints.append(point)
      trimConsumedButtonPoints(&pendingInput.consumedButtonPoints)
    }
    pendingButtonInput = pendingInput
  }

  private func shouldPromotePendingButtonInputToGesture(
    from start: GesturePoint,
    to next: GesturePoint
  ) -> Bool {
    guard GestureMovementResolver.dominantAxisDirection(from: start, to: next) != nil else {
      return false
    }

    return GestureMovementResolver.maximumAbsoluteAxisDelta(from: start, to: next)
      >= tuning.minimumGestureStartAxisDistance
  }

  private func shouldConsumeButtonInput(for session: GestureSession) -> Bool {
    session.trace.isVisible || !session.trace.directions.isEmpty
      || session.consumedButtonInput.fallbackReplayPoint != nil
  }

  private func releaseStoppedButtonInputIfNeeded() -> Bool {
    guard
      let activeSession = session,
      !activeSession.recognition.isCapturingGesture,
      activeSession.consumedButtonInput.fallbackReplayPoint != nil
    else {
      return false
    }

    configuration.onReplayRequested(
      .dragStart(
        button: configuration.recognitionButton,
        points: activeSession.consumedButtonInput.points
      )
    )
    resetGestureSession()
    return true
  }
}
