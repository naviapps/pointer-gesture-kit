/// A cancellable token that keeps a recognizer observation active.
@MainActor
public final class GestureObservationToken {
  private var onCancel: (@MainActor () -> Void)?

  init(onCancel: @escaping @MainActor () -> Void) {
    self.onCancel = onCancel
  }

  isolated deinit {
    cancel()
  }

  /// Cancels the observation if it is still active.
  public func cancel() {
    guard let onCancel else { return }
    self.onCancel = nil
    onCancel()
  }
}
