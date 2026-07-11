import Foundation

enum GestureRecognizerTiming {
  private static let nanosecondsPerSecond: TimeInterval = 1_000_000_000

  static func taskSleepNanoseconds(for interval: TimeInterval) -> UInt64 {
    guard interval > 0, interval.isFinite else { return 0 }

    let nanoseconds = interval * nanosecondsPerSecond
    guard nanoseconds.isFinite, nanoseconds < TimeInterval(UInt64.max) else {
      return UInt64.max
    }

    return max(1, UInt64(nanoseconds.rounded(.up)))
  }
}
