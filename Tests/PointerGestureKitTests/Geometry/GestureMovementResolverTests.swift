import XCTest

@testable import PointerGestureKit

final class GestureMovementResolverTests: XCTestCase {
  func testMaximumAbsoluteAxisDeltaReturnsZeroWithoutMovement() {
    XCTAssertEqual(
      GestureMovementResolver.maximumAbsoluteAxisDelta(
        from: GesturePoint(x: 10, y: 10),
        to: GesturePoint(x: 10, y: 10)
      ),
      0
    )
  }

  func testMaximumAbsoluteAxisDeltaReturnsLargerAbsoluteCoordinateDelta() {
    XCTAssertEqual(
      GestureMovementResolver.maximumAbsoluteAxisDelta(
        from: GesturePoint(x: 10, y: 10),
        to: GesturePoint(x: -5, y: 30)
      ),
      20
    )
    XCTAssertEqual(
      GestureMovementResolver.maximumAbsoluteAxisDelta(
        from: GesturePoint(x: 10, y: 10),
        to: GesturePoint(x: 35, y: 20)
      ),
      25
    )
  }

  func testDominantAxisDirectionResolvesPureCardinalMovement() {
    assertDominantAxisDirection(to: GesturePoint(x: 10, y: 0), is: .right)
    assertDominantAxisDirection(to: GesturePoint(x: -10, y: 0), is: .left)
    assertDominantAxisDirection(to: GesturePoint(x: 0, y: 10), is: .down)
    assertDominantAxisDirection(to: GesturePoint(x: 0, y: -10), is: .up)
  }

  func testDominantAxisDirectionResolvesOffAxisMovementByLargestAxis() {
    assertDominantAxisDirection(to: GesturePoint(x: 10, y: 9), is: .right)
    assertDominantAxisDirection(to: GesturePoint(x: -10, y: 9), is: .left)
    assertDominantAxisDirection(to: GesturePoint(x: 10, y: 25), is: .down)
    assertDominantAxisDirection(to: GesturePoint(x: -10, y: -25), is: .up)
  }

  func testEqualAxisMovementHasNoDominantAxisDirection() {
    assertNoDominantAxisDirection(to: .zero)
    assertNoDominantAxisDirection(from: GesturePoint(x: 10, y: 10), to: GesturePoint(x: 10, y: 10))
    assertNoDominantAxisDirection(to: GesturePoint(x: 10, y: 10))
    assertNoDominantAxisDirection(to: GesturePoint(x: -10, y: 10))
    assertNoDominantAxisDirection(to: GesturePoint(x: 10, y: -10))
    assertNoDominantAxisDirection(to: GesturePoint(x: -10, y: -10))
  }

  func testDominantAxisDirectionUsesLargestAxisFromStartPoint() {
    XCTAssertEqual(
      GestureMovementResolver.dominantAxisDirection(
        from: GesturePoint(x: 100, y: 100),
        to: GesturePoint(x: 75, y: 110)
      ),
      .left
    )
    XCTAssertEqual(
      GestureMovementResolver.dominantAxisDirection(
        from: GesturePoint(x: 100, y: 100),
        to: GesturePoint(x: 110, y: 125)
      ),
      .down
    )
  }

  private func assertDominantAxisDirection(
    from start: GesturePoint = .zero,
    to end: GesturePoint,
    is expectedDirection: GestureDirection,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      GestureMovementResolver.dominantAxisDirection(from: start, to: end),
      expectedDirection,
      file: file,
      line: line
    )
  }

  private func assertNoDominantAxisDirection(
    from start: GesturePoint = .zero,
    to end: GesturePoint,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertNil(
      GestureMovementResolver.dominantAxisDirection(from: start, to: end),
      file: file,
      line: line
    )
  }
}
