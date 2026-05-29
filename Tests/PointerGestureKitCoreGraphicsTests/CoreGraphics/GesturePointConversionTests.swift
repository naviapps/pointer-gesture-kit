import struct CoreGraphics.CGFloat
import struct CoreGraphics.CGPoint
import PointerGestureKit
import PointerGestureKitCoreGraphics
import XCTest

final class GesturePointConversionTests: XCTestCase {
  func testCGPointPropertyPreservesCoordinates() {
    let point = GesturePoint(x: 12.25, y: -7.5)

    let cgPoint = point.cgPoint

    XCTAssertEqual(cgPoint.x, CGFloat(point.x))
    XCTAssertEqual(cgPoint.y, CGFloat(point.y))
  }

  func testCGPointInitializerPreservesCoordinates() {
    let cgPoint = CGPoint(x: 44.0, y: 18.5)

    let point = GesturePoint(cgPoint)

    XCTAssertEqual(point.x, Double(cgPoint.x))
    XCTAssertEqual(point.y, Double(cgPoint.y))
  }

  func testCGPointInitializerUsesGesturePointCoordinateNormalization() {
    XCTAssertEqual(
      GesturePoint(CGPoint(x: CGFloat.nan, y: 18.5)),
      GesturePoint(x: 0, y: 18.5)
    )
    XCTAssertEqual(
      GesturePoint(CGPoint(x: -7.25, y: CGFloat.infinity)),
      GesturePoint(x: -7.25, y: 0)
    )
  }

  func testCGPointPropertyUsesNormalizedGesturePointCoordinates() {
    let point = GesturePoint(x: Double.nan, y: Double.infinity)

    XCTAssertEqual(point.cgPoint, CGPoint.zero)
  }

  func testRoundTripPreservesFiniteCoordinates() {
    let point = GesturePoint(x: -3.25, y: 9.75)

    XCTAssertEqual(GesturePoint(point.cgPoint), point)
  }
}
