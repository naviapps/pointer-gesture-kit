extension GestureRecognizer {
  enum RecognitionPolicyResult {
    case allowed(context: GestureRecognitionContext?)
    case denied
  }

  func evaluateRecognitionPolicy(
    at location: GesturePoint,
    modifiers: GestureModifierFlags
  ) -> RecognitionPolicyResult {
    let context = configuration.recognitionContext(location)

    guard configuration.isRecognitionEnabled(context) else {
      lastFailure = .recognitionDisabled
      return .denied
    }

    guard isRecordingModeEnabled || configuration.areModifiersSatisfied(modifiers, context) else {
      lastFailure = .modifiersNotSatisfied
      return .denied
    }

    lastFailure = nil
    return .allowed(context: context)
  }
}
