import PointerGestureKit
import XCTest

func assertReplayRequests(
  _ requests: [GestureReplayRequest],
  _ expected: [GestureReplayRequest],
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertEqual(requests, expected, file: file, line: line)
}
