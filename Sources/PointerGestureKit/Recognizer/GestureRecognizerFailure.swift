/// Recognizer failures exposed by ``GestureRecognizer`` state.
public enum GestureRecognizerFailure: Equatable, Sendable {
  /// The event source failed to start.
  case eventSourceStartFailed

  /// Recognition is disabled by host policy.
  case recognitionDisabled

  /// Modifier flags did not satisfy host policy.
  case modifiersNotSatisfied

  /// Pending button input or an active gesture session exceeded the configured duration.
  case gestureSessionExpired
}
