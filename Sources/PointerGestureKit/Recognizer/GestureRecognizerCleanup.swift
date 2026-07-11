@MainActor
final class GestureRecognizerCleanup {
  let eventSource: any GestureEventSource
  let onReplayRequested: @MainActor @Sendable (GestureReplayRequest) -> Void
  var startupRetryTask: Task<Void, Never>?
  var inputExpirationTask: Task<Void, Never>?
  var replayRequest: GestureReplayRequest?

  init(
    eventSource: any GestureEventSource,
    onReplayRequested: @escaping @MainActor @Sendable (GestureReplayRequest) -> Void
  ) {
    self.eventSource = eventSource
    self.onReplayRequested = onReplayRequested
  }

  isolated deinit {
    startupRetryTask?.cancel()
    inputExpirationTask?.cancel()
    if let replayRequest {
      onReplayRequested(replayRequest)
    }
    eventSource.stop()
  }
}
