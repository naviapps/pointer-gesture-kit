import PointerGestureKit

/// Routes normalized input independently of the permission-dependent event-tap lifecycle.
@MainActor
final class GestureEventTapInputDispatch {
  typealias Handler = @MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition

  private var handler: Handler?
  var syntheticEventSuppression = SyntheticEventSuppression()

  func install(handler: @escaping Handler) {
    self.handler = handler
  }

  func stop() {
    handler = nil
    syntheticEventSuppression.removeAll()
  }

  func dispatch(
    _ input: GestureInputEvent,
    sourceSignature: SyntheticEventSignature
  ) -> GestureEventDisposition {
    if syntheticEventSuppression.consumeThrough(sourceSignature) {
      return .passThrough
    }
    guard let handler else { return .passThrough }
    return handler(input)
  }

  func recoverFromTapDisabled(
    input: GestureInputEvent,
    sourceSignature: SyntheticEventSignature
  ) {
    syntheticEventSuppression.removeAll()
    _ = dispatch(input, sourceSignature: sourceSignature)
  }
}
