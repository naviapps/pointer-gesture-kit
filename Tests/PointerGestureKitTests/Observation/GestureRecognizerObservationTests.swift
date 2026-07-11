import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerObservationTests: XCTestCase {
  func testObserveEmitsInitialReadyAndStoppedSnapshots() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var snapshots: [GestureRecognizerState] = []
    let token = recognizer.observe { snapshots.append($0) }
    XCTAssertEqual(snapshots.map(\.status.lifecycle), [.idle])

    recognizer.start()
    await XCTAssertEventually(timeout: 0.2) { snapshots.contains { $0.status.lifecycle == .ready } }
    let snapshotCountAfterStart = snapshots.count

    recognizer.stop()
    await XCTAssertEventually(timeout: 0.2) {
      snapshots.count > snapshotCountAfterStart
        && snapshots.last?.status.lifecycle != .ready
        && snapshots.last?.status.isCapturingGesture == false
    }

    XCTAssertNotEqual(snapshots.last?.status.lifecycle, .ready)
    XCTAssertEqual(snapshots.last?.status.isCapturingGesture, false)
    XCTAssertEqual(snapshots.map(\.status.lifecycle), [.idle, .ready, .idle])

    _ = token
  }

  func testObserveSkipsUnchangedStateAssignments() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var callCount = 0
    let token = recognizer.observe { _ in
      callCount += 1
    }
    XCTAssertEqual(callCount, 1)

    recognizer.isRecordingModeEnabled = false
    await XCTAssertNotEventually(timeout: 0.05) { callCount > 1 }
    XCTAssertEqual(callCount, 1)

    recognizer.isRecordingModeEnabled = true
    await XCTAssertEventually(timeout: 0.2) { callCount >= 2 }
    XCTAssertEqual(callCount, 2)

    recognizer.isRecordingModeEnabled = true
    await XCTAssertNotEventually(timeout: 0.05) { callCount > 2 }
    XCTAssertEqual(callCount, 2)

    _ = token
  }

  func testCancelObservationStopsNotifications() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var callCount = 0
    let token = recognizer.observe { _ in
      callCount += 1
    }

    recognizer.start()
    await XCTAssertEventually(timeout: 0.2) { callCount >= 2 }
    XCTAssertGreaterThanOrEqual(callCount, 2)

    token.cancel()
    let countAfterCancel = callCount

    recognizer.stop()
    await XCTAssertNotEventually(timeout: 0.2) { callCount > countAfterCancel }

    XCTAssertEqual(callCount, countAfterCancel)
  }

  func testObservationTokenIsSendable() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    let token = recognizer.observe { _ in }

    assertSendable(token)
  }

  func testCancelingObservationDuringNotificationDoesNotInterruptDelivery() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var firstToken: GestureObservationToken?
    var firstCallCount = 0
    var secondCallCount = 0

    firstToken = recognizer.observe { _ in
      firstCallCount += 1
      if firstCallCount > 1 {
        firstToken?.cancel()
      }
    }
    let secondToken = recognizer.observe { _ in
      secondCallCount += 1
    }

    recognizer.start()
    await XCTAssertEventually(timeout: 0.2) {
      firstCallCount >= 2 && secondCallCount >= 2
    }

    XCTAssertEqual(firstCallCount, 2)
    XCTAssertEqual(secondCallCount, 2)

    recognizer.stop()
    await XCTAssertEventually(timeout: 0.2) {
      secondCallCount >= 3
    }

    XCTAssertEqual(firstCallCount, 2)
    XCTAssertEqual(secondCallCount, 3)

    _ = secondToken
  }

  func testCancelingAnotherObservationDuringNotificationDoesNotInterruptDelivery() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var secondToken: GestureObservationToken?
    var firstCallCount = 0
    var secondCallCount = 0

    let firstToken = recognizer.observe { _ in
      firstCallCount += 1
      if firstCallCount > 1 {
        secondToken?.cancel()
      }
    }
    secondToken = recognizer.observe { _ in
      secondCallCount += 1
    }

    recognizer.start()
    await XCTAssertEventually(timeout: 0.2) {
      firstCallCount >= 2 && secondCallCount >= 2
    }

    XCTAssertEqual(firstCallCount, 2)
    XCTAssertEqual(secondCallCount, 2)

    _ = firstToken
    _ = secondToken
  }

  func testStateChangeDuringObservationSchedulesFollowUpNotification() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var snapshots: [GestureRecognizerState] = []
    let token = recognizer.observe { state in
      snapshots.append(state)
      if state.status.lifecycle == .ready && !state.status.isRecordingModeEnabled {
        recognizer.isRecordingModeEnabled = true
      }
    }

    recognizer.start()
    await XCTAssertEventually(timeout: 0.2) {
      snapshots.contains { $0.status.isRecordingModeEnabled }
    }

    XCTAssertTrue(snapshots.contains { $0.status.lifecycle == .ready })
    XCTAssertTrue(snapshots.contains { $0.status.isRecordingModeEnabled })

    _ = token
  }

  func testObserverAddedDuringPendingNotificationDoesNotReceiveDuplicateCurrentSnapshot() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var firstObserverSnapshots: [GestureRecognizerState] = []
    let firstToken = recognizer.observe { state in
      firstObserverSnapshots.append(state)
    }

    recognizer.start()

    var secondObserverSnapshots: [GestureRecognizerState] = []
    let secondToken = recognizer.observe { state in
      secondObserverSnapshots.append(state)
    }

    XCTAssertEqual(secondObserverSnapshots.map(\.status.lifecycle), [.ready])

    await XCTAssertEventually(timeout: 0.2) {
      firstObserverSnapshots.map(\.status.lifecycle) == [.idle, .ready]
    }
    await XCTAssertNotEventually(timeout: 0.05) {
      secondObserverSnapshots.count > 1
    }

    XCTAssertEqual(secondObserverSnapshots.map(\.status.lifecycle), [.ready])

    _ = firstToken
    _ = secondToken
  }

  func testDroppingObservationTokenStopsNotifications() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var callCount = 0
    var token: GestureObservationToken? = recognizer.observe { _ in
      callCount += 1
    }
    XCTAssertNotNil(token)
    XCTAssertEqual(callCount, 1)

    token = nil
    await Task.yield()
    recognizer.start()
    await XCTAssertNotEventually(timeout: 0.2) { callCount > 1 }

    XCTAssertEqual(callCount, 1)
  }

  private func makeRecognizer(eventSource: GestureEventSourceDouble) -> GestureRecognizer<UUID> {
    GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration()
    )
  }
}
