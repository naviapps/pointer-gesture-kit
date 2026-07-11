import XCTest

import PointerGestureKit
@testable import PointerGestureKitCoreGraphics

final class GestureEventTapReplayPointCoalescingTests: XCTestCase {
  func testCoalescedReplayDragPointsKeepShortDragsUnchanged() {
    let points = makePoints(count: 4)

    XCTAssertEqual(
      coalescedReplayDragPoints(points, maximumPointCount: 4),
      points
    )
  }

  func testCoalescedReplayDragPointsKeepMaximumSizedDragsUnchanged() {
    let points = makePoints(count: 64)

    XCTAssertEqual(
      coalescedReplayDragPoints(points, maximumPointCount: 64),
      points
    )
  }

  func testCoalescedReplayDragPointsRetainFirstAndLastWithinLimit() {
    let points = makePoints(count: 20)

    let coalesced = coalescedReplayDragPoints(points, maximumPointCount: 6)

    XCTAssertEqual(coalesced.count, 6)
    XCTAssertEqual(coalesced.first, points.first)
    XCTAssertEqual(coalesced.last, points.last)
  }

  func testCoalescedReplayDragPointsKeepsAtLeastEndpoints() {
    let points = makePoints(count: 5)

    let coalesced = coalescedReplayDragPoints(points, maximumPointCount: 1)

    XCTAssertEqual(coalesced, [points[0], points[4]])
  }
}

private func makePoints(count: Int) -> [GesturePoint] {
  (0..<count).map { index in
    GesturePoint(x: Double(index), y: Double(index * 2))
  }
}
