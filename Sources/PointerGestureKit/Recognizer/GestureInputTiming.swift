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
    switch (tuning.maximumGestureSessionDuration, tuning.maximumGestureIdleDuration) {
    case let (.some(total), .some(idle)):
      return max(
        0,
        min(
          total - elapsed(since: startedAt, at: now), idle - elapsed(since: lastMovementAt, at: now)
        ))
    case let (.some(total), .none):
      return max(0, total - elapsed(since: startedAt, at: now))
    case let (.none, .some(idle)):
      return max(0, idle - elapsed(since: lastMovementAt, at: now))
    case (.none, .none):
      return nil
    }
  }

  private func elapsed(since start: ContinuousClock.Instant, at now: ContinuousClock.Instant)
    -> Double
  {
    let components = start.duration(to: now).components
    return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
