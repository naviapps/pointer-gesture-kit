import Foundation

/// A thread-safe cancellable token that keeps a recognizer observation active.
///
/// `cancel()` may be called from any actor. Observer removal is performed on the main actor.
public final class GestureObservationToken: @unchecked Sendable {
  private let lock = NSLock()
  private var onCancel: (@MainActor @Sendable () -> Void)?

  init(onCancel: @escaping @MainActor @Sendable () -> Void) {
    self.onCancel = onCancel
  }

  deinit {
    cancel()
  }

  /// Cancels the observation if it is still active.
  public func cancel() {
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
