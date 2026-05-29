import Foundation
import XCTest

@testable import PointerGestureKit

@MainActor
final class GestureObservationTokenTests: XCTestCase {
  func testCancelOnMainThreadRunsHandlerSynchronouslyOnce() {
    var cancelCount = 0
    var cancelThreadWasMain = false
    let token = GestureObservationToken(onCancel: {
      cancelCount += 1
      cancelThreadWasMain = Thread.isMainThread
    })

    XCTAssertEqual(cancelCount, 0)
    token.cancel()
    XCTAssertEqual(cancelCount, 1)
    XCTAssertTrue(cancelThreadWasMain)

    token.cancel()
    XCTAssertEqual(cancelCount, 1)
  }

  func testDeinitCancelsActiveToken() {
    var cancelCount = 0
    var token: GestureObservationToken? = GestureObservationToken(onCancel: {
      cancelCount += 1
    })

    XCTAssertNotNil(token)
    XCTAssertEqual(cancelCount, 0)
    token = nil
    XCTAssertEqual(cancelCount, 1)
  }

  func testDeinitFromAnotherActorCancelsActiveTokenOnMainThread() async {
    let probe = ObservationCancellationProbe()

    await Task.detached { @Sendable [probe] in
      let token = await MainActor.run {
        probe.makeToken()
      }
      _ = token
    }.value

    await XCTAssertEventually { probe.cancelCount == 1 }
    XCTAssertTrue(probe.cancelThreadWasMain)
  }

  func testDeinitAfterCancelDoesNotCancelAgain() {
    var cancelCount = 0
    var token: GestureObservationToken? = GestureObservationToken(onCancel: {
      cancelCount += 1
    })

    token?.cancel()
    XCTAssertEqual(cancelCount, 1)

    token = nil
    XCTAssertEqual(cancelCount, 1)
  }

  func testCancelFromAnotherActorCancelsOnceOnMainThread() async {
    var cancelCount = 0
    var cancelThreadWasMain = false
    let token = GestureObservationToken(onCancel: {
      cancelCount += 1
      cancelThreadWasMain = Thread.isMainThread
    })

    await Task.detached {
      token.cancel()
    }.value
    await XCTAssertEventually { cancelCount == 1 }
    XCTAssertTrue(cancelThreadWasMain)

    token.cancel()
    XCTAssertEqual(cancelCount, 1)
  }

  func testSendableContractAcceptsToken() {
    let token = GestureObservationToken(onCancel: {})

    assertSendable(token)
  }

  func testDoesNotExposeValueSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureObservationToken.self is any Equatable.Type)
    XCTAssertFalse(GestureObservationToken.self is any Hashable.Type)
    XCTAssertFalse(GestureObservationToken.self is any Codable.Type)
    XCTAssertFalse(GestureObservationToken.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureObservationToken.self is any CaseIterable.Type)
    XCTAssertFalse(GestureObservationToken.self is any Error.Type)
  }
}

@MainActor
private final class ObservationCancellationProbe {
  private(set) var cancelCount = 0
  private(set) var cancelThreadWasMain = false

  func makeToken() -> GestureObservationToken {
    GestureObservationToken(onCancel: {
      self.cancelCount += 1
      self.cancelThreadWasMain = Thread.isMainThread
    })
  }
}
