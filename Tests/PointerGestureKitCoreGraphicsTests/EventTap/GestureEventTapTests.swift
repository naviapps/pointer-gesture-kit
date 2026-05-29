import enum CoreGraphics.CGEventType
import XCTest

@testable import PointerGestureKitCoreGraphics

@MainActor
final class GestureEventTapTests: XCTestCase {
  func testStopIsIdempotentWhenTapIsNotStarted() {
    let tap = GestureEventTap()
    tap.stop()
    tap.stop()
  }

  func testStopClearsPendingSyntheticEventSuppression() {
    let tap = GestureEventTap()

    tap.suppressNextSyntheticEventSignatures([rightMouseUp])
    tap.stop()

    XCTAssertFalse(tap.consumePendingSyntheticEventSignature(rightMouseUp))
  }

  func testStartReturnsFalseWhenCapturedButtonsAreEmpty() {
    let tap = GestureEventTap(capturedButtons: [])

    let didStart = tap.start { _ in .consume }

    XCTAssertFalse(didStart)
  }

  func testDoesNotExposeValueSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureEventTap.self is any Equatable.Type)
    XCTAssertFalse(GestureEventTap.self is any Hashable.Type)
    XCTAssertFalse(GestureEventTap.self is any Codable.Type)
    XCTAssertFalse(GestureEventTap.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureEventTap.self is any CaseIterable.Type)
    XCTAssertFalse(GestureEventTap.self is any Error.Type)
  }
}

private let rightMouseUp = SyntheticEventSignature.replayed(type: .rightMouseUp, button: .secondary)
