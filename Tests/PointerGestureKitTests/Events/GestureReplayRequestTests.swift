import PointerGestureKit
import XCTest

final class GestureReplayRequestTests: XCTestCase {
  func testReplayRequestCasesExposePayloads() {
    assertReplayRequests(
      [.click(button: .secondary, at: GesturePoint(x: 10, y: 20))],
      [.click(button: .secondary, at: GesturePoint(x: 10, y: 20))]
    )
    assertReplayRequests(
      [
        .drag(
          button: .primary,
          points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
        )
      ],
      [
        .drag(
          button: .primary,
          points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
        )
      ]
    )
    assertReplayRequests(
      [.release(button: .middle, at: GesturePoint(x: 30, y: 40))],
      [.release(button: .middle, at: GesturePoint(x: 30, y: 40))]
    )
    assertReplayRequests(
      [
        .dragStart(
          button: .secondary,
          points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
        )
      ],
      [
        .dragStart(
          button: .secondary,
          points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
        )
      ]
    )
  }

  func testSendableContractAcceptsReplayRequests() {
    assertSendable(GestureReplayRequest.click(button: .secondary, at: GesturePoint(x: 10, y: 20)))
    assertSendable(
      GestureReplayRequest.drag(
        button: .secondary,
        points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
      ))
    assertSendable(
      GestureReplayRequest.dragStart(
        button: .secondary,
        points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
      ))
    assertSendable(
      GestureReplayRequest.release(button: .secondary, at: GesturePoint(x: 30, y: 40)))
  }

  func testEquatableContractDistinguishesPayloads() {
    let request = GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20))
    let same = GestureReplayRequest.click(button: .secondary, at: .init(x: 10, y: 20))
    let different = GestureReplayRequest.drag(
      button: .secondary,
      points: [GesturePoint(x: 10, y: 20), GesturePoint(x: 20, y: 20)]
    )

    XCTAssertEqual(request, same)
    XCTAssertNotEqual(request, different)
  }

  func testEqualityUsesCaseButtonAndPayload() {
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
      GestureReplayRequest.dragStart(
        button: .secondary,
        points: [.init(x: 10, y: 20), .init(x: 20, y: 20)]
      )
    )
    XCTAssertNotEqual(
      GestureReplayRequest.dragStart(
        button: .secondary,
        points: [.init(x: 10, y: 20), .init(x: 20, y: 20)]
      ),
      GestureReplayRequest.dragStart(
        button: .secondary,
        points: [.init(x: 10, y: 20), .init(x: 21, y: 20)]
      )
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

}
