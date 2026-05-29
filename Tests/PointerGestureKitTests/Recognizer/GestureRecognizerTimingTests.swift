import Foundation
import XCTest

@testable import PointerGestureKit

final class GestureRecognizerTimingTests: XCTestCase {
  func testTaskSleepNanosecondsRejectsNonPositiveAndNonFiniteIntervals() {
    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: -1), 0)
    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: 0), 0)
    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: .nan), 0)
    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: .infinity), 0)
  }

  func testTaskSleepNanosecondsRoundsPositiveIntervalsUp() {
    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: 0.000_000_000_1), 1)
    XCTAssertEqual(
      GestureRecognizerTiming.sleepNanoseconds(for: 1.000_000_000_1),
      1_000_000_001
    )
    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: 1.25), 1_250_000_000)
  }

  func testTaskSleepNanosecondsClampsOverflow() {
    XCTAssertEqual(
      GestureRecognizerTiming.sleepNanoseconds(for: .greatestFiniteMagnitude),
      UInt64.max
    )
  }

  func testTaskSleepNanosecondsClampsUInt64Boundary() {
    let boundary = TimeInterval(UInt64.max) / 1_000_000_000

    XCTAssertEqual(GestureRecognizerTiming.sleepNanoseconds(for: boundary), UInt64.max)
  }
}
