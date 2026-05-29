import PointerGestureKit
import XCTest

final class GestureReplayRequestTests: XCTestCase {
  func testCasesCarryReplayLocations() {
    XCTAssertEqual(
      GestureReplayRequest.click(button: .secondary, at: GesturePoint(x: 10, y: 20)).location,
      GesturePoint(x: 10, y: 20)
    )
    XCTAssertEqual(
      GestureReplayRequest.release(button: .secondary, at: GesturePoint(x: 30, y: 40)).location,
      GesturePoint(x: 30, y: 40)
    )
    XCTAssertEqual(
      GestureReplayRequest.drag(
        button: .secondary,
        points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 30, y: 40)]
      ).location,
      GesturePoint(x: 30, y: 40)
    )
  }

  func testCasesCarryReplayButtons() {
    XCTAssertEqual(
      GestureReplayRequest.click(button: .primary, at: GesturePoint(x: 10, y: 20)).button,
      .primary
    )
    XCTAssertEqual(
      GestureReplayRequest.drag(button: .middle, points: [GesturePoint(x: 10, y: 20)]).button,
      .middle
    )
    XCTAssertEqual(
      GestureReplayRequest.release(button: .secondary, at: GesturePoint(x: 30, y: 40)).button,
      .secondary
    )
  }

  func testEmptyDragRequestHasNoLocation() {
    XCTAssertNil(GestureReplayRequest.drag(button: .secondary, points: []).location)
  }

  func testEqualityUsesCaseAndLocation() {
    XCTAssertEqual(
      GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20)),
      GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20))
    )
    XCTAssertNotEqual(
      GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20)),
      GestureReplayRequest.release(button: .secondary, at: .init(x: 10, y: 20))
    )
    XCTAssertNotEqual(
      GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20)),
      GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 21))
    )
    XCTAssertNotEqual(
      GestureReplayRequest.click(button: .primary, at: .init(x: 10, y: 20)),
      GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20))
    )
    XCTAssertNotEqual(
      GestureReplayRequest.drag(
        button: .secondary,
        points: [.init(x: 10, y: 20), .init(x: 20, y: 20)]
      ),
      GestureReplayRequest.drag(
        button: .secondary,
        points: [.init(x: 10, y: 20), .init(x: 21, y: 20)]
      )
    )
  }

  func testHashableContractSupportsCollections() {
    let request = GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20))
    let same = GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20))
    let different = GestureReplayRequest.drag(
      button: .secondary,
      points: [.init(x: 10, y: 20), .init(x: 20, y: 20)]
    )

    XCTAssertEqual(Set([request, same, different]), [request, different])
  }

  func testSendableContractAcceptsReplayRequests() {
    assertSendable(GestureReplayRequest.click(button: .secondary, at: GesturePoint(x: 10, y: 20)))
    assertSendable(
      GestureReplayRequest.drag(
        button: .secondary,
        points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
      ))
    assertSendable(
      GestureReplayRequest.release(button: .secondary, at: GesturePoint(x: 30, y: 40)))
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureReplayRequest.self is any Codable.Type)
    XCTAssertFalse(GestureReplayRequest.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureReplayRequest.self is any CaseIterable.Type)
    XCTAssertFalse(GestureReplayRequest.self is any Error.Type)
  }
}
