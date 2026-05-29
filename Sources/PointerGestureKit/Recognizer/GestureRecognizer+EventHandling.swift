extension GestureRecognizer {
  private var isTrackingButtonInput: Bool {
    pendingButtonInput != nil || session != nil
  }

  func handleInputEvent(_ event: GestureInputEvent) -> GestureEventDisposition {
    guard isReady else { return .passThrough }

    switch event.kind {
    case let .buttonDown(button):
      guard button == recognitionButton else { return .passThrough }
      guard !isTrackingButtonInput else {
        return .consume
      }

      let policyResult = validateGestureStartPolicy(
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

    case let .buttonDragged(button):
      guard button == recognitionButton else { return .passThrough }
      return continueButtonInput(at: event.location)

    case let .buttonUp(button):
      guard button == recognitionButton else { return .passThrough }
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
    pendingButtonInput = PendingButtonInput(
      startPoint: location,
      consumedButtonPoints: [location],
      recognitionContext: recognitionContext
    )
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
        context: pendingInput.recognitionContext
      )
      pendingButtonInput = nil
    }

    updateGestureSession(to: location)

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
      if hasPendingButtonMovement {
        appendPendingButtonInputPoint(location)
      }
      return requestPendingButtonInputReplay()
    }

    if !activeSession.consumedButtonInput.isConsumingInput {
      resetGestureSession()
      return .passThrough
    }

    let outcome = completeGestureSession(at: location)
    if let match = outcome.match {
      onMatch(match)
    }
    onReplayRequested(outcome.replayRequest)
    return .consume
  }

  private func requestPendingButtonInputReplay() -> GestureEventDisposition {
    guard let pendingInput = pendingButtonInput else { return .passThrough }
    pendingButtonInput = nil
    requestConsumedButtonInputReplay(
      pendingInput.consumedButtonPoints,
      clickAt: pendingInput.startPoint
    )
    return .consume
  }

  private func appendPendingButtonInputPoint(_ point: GesturePoint) {
    guard var pendingInput = pendingButtonInput else { return }
    if pendingInput.consumedButtonPoints.last != point {
      pendingInput.consumedButtonPoints.append(point)
    }
    pendingButtonInput = pendingInput
  }

  private var hasPendingButtonMovement: Bool {
    guard let pendingInput = pendingButtonInput else { return false }
    return pendingInput.consumedButtonPoints.count > 1
  }

  private func shouldPromotePendingButtonInputToGesture(
    from start: GesturePoint,
    to next: GesturePoint
  ) -> Bool {
    guard GestureMovementResolver.dominantDirection(from: start, to: next) != nil else {
      return false
    }

    let movementThreshold: Double =
      if isRecordingModeEnabled {
        tuning.minimumGestureStartAxisDistance
      } else {
        max(tuning.minimumGestureStartAxisDistance, tuning.minimumDirectionChangeAxisDistance)
      }
    return GestureMovementResolver.maximumAxisDelta(from: start, to: next) > movementThreshold
  }

  private func shouldConsumeButtonInput(for session: GestureSession) -> Bool {
    session.trace.isVisible || !session.trace.directions.isEmpty
      || session.consumedButtonInput.fallbackReplayPoint != nil
  }
}
