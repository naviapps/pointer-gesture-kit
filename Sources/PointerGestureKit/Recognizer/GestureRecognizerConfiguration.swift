/// Host-owned callbacks, policy, and tuning used to create a ``GestureRecognizer``.
public struct GestureRecognizerConfiguration<Match: Sendable>: Sendable {
  /// Returns a matcher for the active host-defined recognition context.
  ///
  /// Recording mode records directions without requesting a matcher.
  let makeMatcher: @MainActor @Sendable (GestureRecognitionContext?) -> GesturePatternMatcher<Match>
  /// The pointer button that starts gesture recognition.
  let recognitionButton: PointerButton
  /// Called when consumed pointer-button input should be replayed.
  let onReplayRequested: @MainActor @Sendable (GestureReplayRequest) -> Void
  /// Called when a registered pattern is matched.
  let onMatch: @MainActor @Sendable (Match) -> Void
  /// Returns the host-defined recognition context for a pointer location.
  let recognitionContext: @MainActor @Sendable (GesturePoint) -> GestureRecognitionContext?
  /// Returns whether gestures may run for the active context.
  ///
  /// This policy is evaluated in both normal recognition and recording mode.
  let isRecognitionEnabled: @MainActor @Sendable (GestureRecognitionContext?) -> Bool
  /// Whether normal recognition should pass input through when no pattern can match.
  let passesThroughEmptyMatcher: Bool
  /// Returns whether the current modifier flags satisfy the host policy.
  ///
  /// Recording mode bypasses this policy after recognition is enabled for the active context.
  let areModifiersSatisfied:
    @MainActor @Sendable (GestureModifierFlags, GestureRecognitionContext?) -> Bool
  /// Recognition thresholds, runtime limits, and event-source start retry tuning.
  let tuning: GestureRecognizerTuning

  /// Creates a recognizer configuration from host-owned callbacks, policy, and tuning.
  ///
  /// - Parameters:
  ///   - makeMatcher: Returns the direction matcher for the active host-defined context. Recording
  ///     mode records directions without requesting a matcher.
  ///   - onReplayRequested: Handles replay requests for consumed pointer-button input.
  ///   - onMatch: Handles the app-owned match value for a recognized pattern.
  ///   - recognitionButton: The pointer button that starts gesture recognition.
  ///   - recognitionContext: Returns the host-defined context for the gesture start location.
  ///   - isRecognitionEnabled: Returns whether recognition may run for the active context. This
  ///     policy is evaluated in both normal recognition and recording mode.
  ///   - passesThroughEmptyMatcher: When true, normal recognition leaves pointer-button input
  ///     untouched if the matcher for the active context has no registered patterns.
  ///   - areModifiersSatisfied: Returns whether the current modifier flags satisfy host policy.
  ///     Recording mode bypasses this policy after recognition is enabled for the active context.
  ///   - tuning: Recognition thresholds, runtime limits, and event-source start retry tuning.
  public init(
    makeMatcher:
      @escaping @MainActor @Sendable (GestureRecognitionContext?) -> GesturePatternMatcher<Match>,
    onReplayRequested: @escaping @MainActor @Sendable (GestureReplayRequest) -> Void,
    onMatch: @escaping @MainActor @Sendable (Match) -> Void,
    recognitionButton: PointerButton = .secondary,
    recognitionContext:
      @escaping @MainActor @Sendable (GesturePoint) -> GestureRecognitionContext? = { _ in nil },
    isRecognitionEnabled: @escaping @MainActor @Sendable (GestureRecognitionContext?) -> Bool = {
      _ in true
    },
    passesThroughEmptyMatcher: Bool = false,
    areModifiersSatisfied:
      @escaping @MainActor @Sendable (GestureModifierFlags, GestureRecognitionContext?) -> Bool = {
        _, _ in true
      },
    tuning: GestureRecognizerTuning = .standard
  ) {
    self.makeMatcher = makeMatcher
    self.recognitionButton = recognitionButton
    self.onReplayRequested = onReplayRequested
    self.onMatch = onMatch
    self.recognitionContext = recognitionContext
    self.isRecognitionEnabled = isRecognitionEnabled
    self.passesThroughEmptyMatcher = passesThroughEmptyMatcher
    self.areModifiersSatisfied = areModifiersSatisfied
    self.tuning = tuning
  }
}
