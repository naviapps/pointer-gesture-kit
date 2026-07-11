import Foundation

extension GestureRecognizer {
  enum LifecycleState: Equatable {
    case idle
    case starting
    case ready
    case retrying
    case failed
  }

  struct GestureSession {
    var sessionID: UUID
    var startPoint: GesturePoint
    var trace: GestureSessionTraceState
    var recognition: GestureSessionRecognitionState
    var consumedButtonInput: ConsumedButtonInputState
  }

  struct GestureSessionRecognitionState {
    var matcherCursor: GesturePatternMatcher<Match>?
    var isRecordingSession: Bool
    var isCapturingGesture: Bool
  }

  struct GestureSessionTraceState {
    var rawPoints: [GesturePoint]
    var publishedRawPointCount: Int
    var directionEndpoints: [GesturePoint]
    var directions: [GestureDirection]
    var tailPoint: GesturePoint?
    var isVisible: Bool
  }

  struct ConsumedButtonInputState {
    var points: [GesturePoint]
    var fallbackReplayPoint: GesturePoint?
    var isConsumingInput: Bool
  }

  struct PendingButtonInput {
    var inputID: UUID
    var startPoint: GesturePoint
    var consumedButtonPoints: [GesturePoint]
    var matcherCursor: GesturePatternMatcher<Match>?
    var isRecordingSession: Bool
  }
}
