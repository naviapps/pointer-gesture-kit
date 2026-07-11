import CoreGraphics
import PointerGestureKit
import PointerGestureKitCoreGraphics
import XCTest

@MainActor
final class PointerGestureKitCoreGraphicsPublicAPITests: XCTestCase {
  func testCoreGraphicsAdapterAPIsAreUsableFromPublicImport() {
    let point = GesturePoint(CGPoint(x: 10, y: 20))
    let eventTap = GestureEventTap(capturedButtons: [.primary])
    let eventSource: any GestureEventSource = eventTap
    let replay: (GestureReplayRequest) -> Void = eventTap.replay

    XCTAssertEqual(point, GesturePoint(x: 10, y: 20))
    XCTAssertEqual(point.cgPoint, CGPoint(x: 10, y: 20))
    XCTAssertFalse(GesturePoint(CGPoint(x: CGFloat.nan, y: 20)).isFinite)
    XCTAssertTrue(eventSource === eventTap)
    XCTAssertFalse(GestureEventTap(capturedButtons: []).start { _ in .consume })
    eventTap.stop()
    _ = replay
  }

  func testDocumentationExamplesAreUsableWithoutTestableImport() {
    let gesturePoint = GesturePoint(CGPoint(x: 10, y: 20))
    let cgPoint = gesturePoint.cgPoint
    let eventTap = GestureEventTap(capturedButtons: [.secondary])
    let replay: (GestureReplayRequest) -> Void = eventTap.replay

    replay(.click(button: .secondary, at: gesturePoint))

    XCTAssertEqual(cgPoint, CGPoint(x: 10, y: 20))
    XCTAssertNotNil(eventTap)
  }

}
