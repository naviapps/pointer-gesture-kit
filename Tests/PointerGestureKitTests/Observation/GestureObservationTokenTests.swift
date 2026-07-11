import XCTest

@testable import PointerGestureKit

@MainActor
final class GestureObservationTokenTests: XCTestCase {
  func testCancelRunsHandlerSynchronouslyOnce() {
    var cancelCount = 0
    let token = GestureObservationToken(onCancel: {
      cancelCount += 1
    })

    token.cancel()
    token.cancel()

    XCTAssertEqual(cancelCount, 1)
  }

  func testDeinitCancelsActiveTokenOnce() async {
    var cancelCount = 0
    var token: GestureObservationToken? = GestureObservationToken(onCancel: {
      cancelCount += 1
    })

    XCTAssertNotNil(token)
    token = nil

    await XCTAssertEventually { cancelCount == 1 }
    XCTAssertEqual(cancelCount, 1)
  }

  func testSendableContractAcceptsToken() {
    let token = GestureObservationToken(onCancel: {})

    assertSendable(token)
  }

}
