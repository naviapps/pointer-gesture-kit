import Foundation
import XCTest

@testable import PointerGestureKit

final class GestureRecognizerTimingTests: XCTestCase {
  func testTaskSleepNanosecondsRejectsNonPositiveAndNonFiniteIntervals() {
    XCTAssertEqual(GestureRecognizerTiming.taskSleepNanoseconds(for: -1), 0)
    XCTAssertEqual(GestureRecognizerTiming.taskSleepNanoseconds(for: 0), 0)
    XCTAssertEqual(GestureRecognizerTiming.taskSleepNanoseconds(for: .nan), 0)
    XCTAssertEqual(GestureRecognizerTiming.taskSleepNanoseconds(for: .infinity), 0)
  }

  func testTaskSleepNanosecondsRoundsPositiveIntervalsUp() {
    XCTAssertEqual(GestureRecognizerTiming.taskSleepNanoseconds(for: 0.000_000_000_1), 1)
    XCTAssertEqual(GestureRecognizerTiming.taskSleepNanoseconds(for: 1.25), 1_250_000_000)
    XCTAssertEqual(
      GestureRecognizerTiming.taskSleepNanoseconds(for: 1.000_000_000_1),
      1_000_000_001
    )
  }

  func testTaskSleepNanosecondsClampsOverflow() {
    XCTAssertEqual(
      GestureRecognizerTiming.taskSleepNanoseconds(for: .greatestFiniteMagnitude),
      UInt64.max
    )
  }
}
