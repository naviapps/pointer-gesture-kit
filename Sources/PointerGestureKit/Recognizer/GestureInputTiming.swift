import Foundation

/// Continuous time avoids wall-clock changes and one timer task per pointer event.
struct GestureInputTiming {
  let startedAt: ContinuousClock.Instant
  private(set) var lastMovementAt: ContinuousClock.Instant

  init(now: ContinuousClock.Instant = .now) {
    startedAt = now
    lastMovementAt = now
  }

  mutating func noteMovement(now: ContinuousClock.Instant = .now) {
    lastMovementAt = now
  }

  func remainingDuration(
    tuning: GestureRecognizerTuning,
    now: ContinuousClock.Instant = .now
  ) -> TimeInterval? {
    let total = tuning.maximumGestureSessionDuration.map { $0 - elapsed(since: startedAt, at: now) }
    let idle = tuning.maximumGestureIdleDuration.map {
      $0 - elapsed(since: lastMovementAt, at: now)
    }
    return [total, idle].compactMap { $0 }.min().map { max(0, $0) }
  }

  private func elapsed(since start: ContinuousClock.Instant, at now: ContinuousClock.Instant)
    -> Double
  {
    let components = start.duration(to: now).components
    return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
