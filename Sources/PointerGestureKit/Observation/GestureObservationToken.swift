import Foundation

/// A cancellable token that keeps a recognizer observation active.
@MainActor
public final class GestureObservationToken {
  private let cleanup: GestureObservationTokenCleanup

  init(onCancel: @escaping @MainActor @Sendable () -> Void) {
    cleanup = GestureObservationTokenCleanup(onCancel: onCancel)
  }

  /// Cancels the observation if it is still active.
  public func cancel() {
    cleanup.cancel()
  }
}

private final class GestureObservationTokenCleanup: @unchecked Sendable {
  private let lock = NSLock()
  private var onCancel: (@MainActor @Sendable () -> Void)?

  init(onCancel: @escaping @MainActor @Sendable () -> Void) {
    self.onCancel = onCancel
  }

  deinit {
    cancel()
  }

  func cancel() {
    lock.lock()
    let onCancel = onCancel
    self.onCancel = nil
    lock.unlock()

    guard let onCancel else { return }
    if Thread.isMainThread {
      MainActor.assumeIsolated {
        onCancel()
      }
    } else {
      Task { @MainActor in
        onCancel()
      }
    }
  }
}
