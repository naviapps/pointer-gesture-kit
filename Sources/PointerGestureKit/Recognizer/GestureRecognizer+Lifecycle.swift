extension GestureRecognizer {
  /// Starts gesture recognition.
  ///
  /// Calling this while the recognizer is already ready has no effect. When the event source cannot start,
  /// the recognizer records ``GestureRecognizerFailure/eventSourceStartFailed``. It follows the
  /// configured retry schedule when retry delays are present, or moves to a failed lifecycle when
  /// no retry delay is configured.
  public func start() {
    guard lifecycleState != .ready else { return }

    startRequested = true
    cancelStartupRetry()
    attemptStartupOrScheduleRetry()
  }

  /// Stops gesture recognition and clears active state.
  ///
  /// This cancels pending startup retries, clears pending gesture state, and requests a release
  /// replay when an active gesture session is holding consumed pointer-button input.
  public func stop() {
    guard lifecycleState != .idle || startRequested else { return }

    startRequested = false
    lifecycleState = .idle
    stopRuntimeResources()
    lastFailure = nil
  }

  /// Immediately retries startup after a previous ``start()`` request.
  ///
  /// Calling this before ``start()`` or while the recognizer is ready has no effect.
  public func retryStartNow() {
    guard startRequested, !isReady else { return }

    cancelStartupRetry()
    attemptStartupOrScheduleRetry()
  }

  /// Cancels the active gesture session and releases any held pointer-button state.
  ///
  /// Calling this while no gesture session or pending button input exists has no effect and
  /// preserves the current failure state.
  public func cancelActiveGesture() {
    guard session != nil || pendingButtonInput != nil else { return }

    cancelGestureSession()
  }

  private func attemptEventSourceStart() -> Bool {
    eventSource.start { [weak self] input in
      guard let self else { return .passThrough }
      return handleInputEvent(input)
    }
  }

  func stopRuntimeResources() {
    cancelStartupRetry()
    requestConsumedButtonInputReplayIfNeeded()
    resetGestureSession()
    eventSource.stop()
  }

  private func attemptStartupOrScheduleRetry() {
    lifecycleState = .starting

    if attemptEventSourceStart() {
      finalizeSuccessfulStart()
    } else {
      recordEventSourceStartFailure()
      scheduleStartupRetry()
    }
  }

  private func finalizeSuccessfulStart() {
    lastFailure = nil
    lifecycleState = .ready
  }

  private func recordEventSourceStartFailure() {
    lifecycleState = tuning.eventSourceStartRetryDelays.isEmpty ? .failed : .retrying
    lastFailure = .eventSourceStartFailed
  }

  private func scheduleStartupRetry() {
    cancelStartupRetry()
    guard startRequested, !tuning.eventSourceStartRetryDelays.isEmpty else { return }

    startupRetryTask = Task { [weak self] in
      guard let self else { return }
      var attempt = 0

      while !Task.isCancelled {
        let retryDelays = tuning.eventSourceStartRetryDelays
        let delay = retryDelays[min(attempt, retryDelays.count - 1)]
        attempt += 1

        if delay > 0 {
          try? await Task.sleep(nanoseconds: GestureRecognizerTiming.sleepNanoseconds(for: delay))
        } else {
          await Task.yield()
        }

        guard !Task.isCancelled else { return }

        let retryLoopDidFinish = await MainActor.run {
          self.attemptScheduledStartupRetry()
        }

        if retryLoopDidFinish {
          return
        }
      }
    }
  }

  @MainActor
  private func attemptScheduledStartupRetry() -> Bool {
    if !startRequested {
      lastFailure = nil
      startupRetryTask = nil
      lifecycleState = .idle
      return true
    }

    if isReady {
      lastFailure = nil
      startupRetryTask = nil
      lifecycleState = .ready
      return true
    }

    if attemptEventSourceStart() {
      finalizeSuccessfulStart()
      startupRetryTask = nil
      return true
    } else {
      recordEventSourceStartFailure()
      return false
    }
  }

  private func cancelStartupRetry() {
    startupRetryTask?.cancel()
    startupRetryTask = nil
  }
}
