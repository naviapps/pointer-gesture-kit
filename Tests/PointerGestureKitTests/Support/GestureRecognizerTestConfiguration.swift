import PointerGestureKit

@MainActor
func makeGestureRecognizerTestConfiguration<Match: Sendable>(
  makeMatcher:
    @escaping @MainActor @Sendable (GestureRecognitionContext?) -> GesturePatternMatcher<Match> = {
      _ in GesturePatternMatcher<Match>()
    },
  onReplayRequested: @escaping @MainActor @Sendable (GestureReplayRequest) -> Void = { _ in },
  onMatch: @escaping @MainActor @Sendable (Match) -> Void = { _ in },
  recognitionButton: PointerButton = .secondary,
  recognitionContext: @escaping @MainActor @Sendable (GesturePoint) -> GestureRecognitionContext? =
    { _ in nil },
  isRecognitionEnabled: @escaping @MainActor @Sendable (GestureRecognitionContext?) -> Bool = {
    _ in true
  },
  passesThroughEmptyMatcher: Bool = false,
  areModifiersSatisfied:
    @escaping @MainActor @Sendable (
      GestureModifierFlags,
      GestureRecognitionContext?
    ) -> Bool = { _, _ in true },
  tuning: GestureRecognizerTuning = .testing()
) -> GestureRecognizerConfiguration<Match> {
  GestureRecognizerConfiguration<Match>(
    makeMatcher: makeMatcher,
    onReplayRequested: onReplayRequested,
    onMatch: onMatch,
    recognitionButton: recognitionButton,
    recognitionContext: recognitionContext,
    isRecognitionEnabled: isRecognitionEnabled,
    passesThroughEmptyMatcher: passesThroughEmptyMatcher,
    areModifiersSatisfied: areModifiersSatisfied,
    tuning: tuning
  )
}
