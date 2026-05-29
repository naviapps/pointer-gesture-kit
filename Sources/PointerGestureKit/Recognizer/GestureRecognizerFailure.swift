/// Recognizer failures exposed by ``GestureRecognizer`` state.
public enum GestureRecognizerFailure: Hashable, Sendable {
  /// The event source failed to start.
  case eventSourceStartFailed
  /// Recognition is disabled by host policy.
  case recognitionDisabled
  /// Modifier keys did not satisfy host policy.
  case modifiersNotSatisfied
  /// The active gesture session exceeded the configured duration.
  case gestureSessionExpired
}
