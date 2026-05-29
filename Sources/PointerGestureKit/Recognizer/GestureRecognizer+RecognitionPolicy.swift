extension GestureRecognizer {
  enum GestureStartPolicyResult {
    case allowed(context: GestureRecognitionContext?)
    case denied
  }

  func validateGestureStartPolicy(
    at location: GesturePoint,
    modifiers: GestureModifierFlags
  ) -> GestureStartPolicyResult {
    let context = recognitionContext(location)

    guard isRecognitionEnabled(context) else {
      lastFailure = .recognitionDisabled
      return .denied
    }

    guard isRecordingModeEnabled || areModifiersSatisfied(modifiers, context) else {
      lastFailure = .modifiersNotSatisfied
      return .denied
    }

    lastFailure = nil
    return .allowed(context: context)
  }
}
