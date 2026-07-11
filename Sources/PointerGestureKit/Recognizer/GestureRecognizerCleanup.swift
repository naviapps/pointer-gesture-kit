import Foundation

final class GestureRecognizerCleanup {
  private let eventSource: GestureEventSourceReference
  let onReplayRequested: @MainActor @Sendable (GestureReplayRequest) -> Void
  var startupRetryTask: Task<Void, Never>?
  var inputExpirationTask: Task<Void, Never>?
  var replayRequest: GestureReplayRequest?

  @MainActor
  init(
    eventSource: any GestureEventSource,
    onReplayRequested: @escaping @MainActor @Sendable (GestureReplayRequest) -> Void
  ) {
    self.eventSource = GestureEventSourceReference(eventSource)
    self.onReplayRequested = onReplayRequested
  }

  deinit {
    startupRetryTask?.cancel()
    inputExpirationTask?.cancel()

    let cleanup = GestureRecognizerDeinitCleanup(
      eventSource: eventSource,
      onReplayRequested: onReplayRequested,
      replayRequest: replayRequest
    )
    if Thread.isMainThread {
      MainActor.assumeIsolated {
        cleanup.run()
      }
    } else {
      Task { @MainActor in
        cleanup.run()
      }
    }
  }
}

private struct GestureRecognizerDeinitCleanup: Sendable {
  let eventSource: GestureEventSourceReference
  let onReplayRequested: @MainActor @Sendable (GestureReplayRequest) -> Void
  let replayRequest: GestureReplayRequest?

  @MainActor
  func run() {
    if let replayRequest {
      onReplayRequested(replayRequest)
    }
    eventSource.value.stop()
  }
}

private struct GestureEventSourceReference: @unchecked Sendable {
  let value: any GestureEventSource

  @MainActor
  init(_ value: any GestureEventSource) {
    self.value = value
  }
}
