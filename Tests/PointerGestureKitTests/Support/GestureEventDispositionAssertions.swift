import PointerGestureKit
import XCTest

func assertDisposition(
  _ disposition: @autoclosure () -> GestureEventDisposition,
  _ expected: GestureEventDisposition,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertEqual(disposition(), expected, file: file, line: line)
}
