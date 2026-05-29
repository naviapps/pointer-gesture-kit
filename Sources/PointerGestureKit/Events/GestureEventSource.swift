/// Supplies normalized input events from a live platform source.
@MainActor
public protocol GestureEventSource: AnyObject, Sendable {
  /// Starts the event source with the supplied event handler.
  ///
  /// Implementations should pass normalized input events to the handler and apply the returned
  /// disposition to the original platform event: ``GestureEventDisposition/consume`` suppresses
  /// it, and ``GestureEventDisposition/passThrough`` leaves it in the platform event stream.
  /// A successful start replaces any previously active handler.
  /// Returns `false` when the source cannot start, for example because the host app lacks required
  /// platform permission. A source that returns `false` must not deliver events until a later
  /// successful start.
  func start(handler: @escaping @MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition)
    -> Bool

  /// Stops the event source and releases any live input resources.
  ///
  /// Calling `stop()` when the source is already stopped must be safe. Stopped sources must not
  /// deliver events until a later successful start.
  func stop()
}
