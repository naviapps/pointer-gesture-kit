import XCTest

@testable import PointerGestureKit

final class GestureMovementResolverTests: XCTestCase {
  func testMaximumAxisDeltaReturnsZeroWithoutMovement() {
    XCTAssertEqual(
      GestureMovementResolver.maximumAxisDelta(
        from: GesturePoint(x: 10, y: 10),
        to: GesturePoint(x: 10, y: 10)
      ),
      0
    )
  }

  func testMaximumAxisDeltaReturnsLargerAbsoluteCoordinateDelta() {
    XCTAssertEqual(
      GestureMovementResolver.maximumAxisDelta(
        from: GesturePoint(x: 10, y: 10),
        to: GesturePoint(x: -5, y: 30)
      ),
      20
    )
    XCTAssertEqual(
      GestureMovementResolver.maximumAxisDelta(
        from: GesturePoint(x: 10, y: 10),
        to: GesturePoint(x: 35, y: 20)
      ),
      25
    )
  }

  func testDominantDirectionResolvesPureCardinalMovement() {
    assertDominantDirection(to: GesturePoint(x: 10, y: 0), is: .right)
    assertDominantDirection(to: GesturePoint(x: -10, y: 0), is: .left)
    assertDominantDirection(to: GesturePoint(x: 0, y: 10), is: .down)
    assertDominantDirection(to: GesturePoint(x: 0, y: -10), is: .up)
  }

  func testZeroDeltaHasNoDirection() {
    assertNoDominantDirection(to: .zero)
    assertNoDominantDirection(from: GesturePoint(x: 10, y: 10), to: GesturePoint(x: 10, y: 10))
  }

  func testHorizontalDominantMovementResolvesHorizontally() {
    assertDominantDirection(to: GesturePoint(x: 10, y: 9), is: .right)
    assertDominantDirection(to: GesturePoint(x: -10, y: 9), is: .left)
    assertDominantDirection(to: GesturePoint(x: 10, y: -9), is: .right)
    assertDominantDirection(to: GesturePoint(x: -10, y: -9), is: .left)
  }

  func testEqualAxisMovementHasNoDominantDirection() {
    assertNoDominantDirection(to: GesturePoint(x: 10, y: 10))
    assertNoDominantDirection(to: GesturePoint(x: -10, y: 10))
    assertNoDominantDirection(to: GesturePoint(x: 10, y: -10))
    assertNoDominantDirection(to: GesturePoint(x: -10, y: -10))
  }

  func testVerticalDominantMovementResolvesVertically() {
    assertDominantDirection(to: GesturePoint(x: 10, y: 25), is: .down)
    assertDominantDirection(to: GesturePoint(x: 10, y: -25), is: .up)
    assertDominantDirection(to: GesturePoint(x: -10, y: 25), is: .down)
    assertDominantDirection(to: GesturePoint(x: -10, y: -25), is: .up)
  }

  func testDominantDirectionUsesStartPoint() {
    XCTAssertEqual(
      GestureMovementResolver.dominantDirection(
        from: GesturePoint(x: 100, y: 100),
        to: GesturePoint(x: 75, y: 110)
      ),
      .left
    )
  }

  private func assertDominantDirection(
    from start: GesturePoint = .zero,
    to end: GesturePoint,
    is expectedDirection: GestureDirection,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      GestureMovementResolver.dominantDirection(from: start, to: end),
      expectedDirection,
      file: file,
      line: line
    )
  }

  private func assertNoDominantDirection(
    from start: GesturePoint = .zero,
    to end: GesturePoint,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertNil(
      GestureMovementResolver.dominantDirection(from: start, to: end),
      file: file,
      line: line
    )
  }
}
