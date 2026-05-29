import Foundation
import PointerGestureKit

extension GestureRecognizerTuning {
  static func testing(
    minimumGestureStartAxisDistance: Double = 10.0,
    minimumDirectionChangeAxisDistance: Double = 25.0,
    maximumGestureSessionDuration: TimeInterval? = nil,
    maximumRawPointCount: Int = 1000,
    eventSourceStartRetryDelays: [TimeInterval] = []
  ) -> Self {
    Self(
      minimumGestureStartAxisDistance: minimumGestureStartAxisDistance,
      minimumDirectionChangeAxisDistance: minimumDirectionChangeAxisDistance,
      maximumGestureSessionDuration: maximumGestureSessionDuration,
      maximumRawPointCount: maximumRawPointCount,
      eventSourceStartRetryDelays: eventSourceStartRetryDelays
    )
  }
}
