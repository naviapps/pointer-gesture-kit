import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerRetryStartNowTests: XCTestCase {
  func testRetryStartNowDoesNothingBeforeStart() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.retryStartNow()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertEqual(eventSource.startCount, 0)
  }

  func testRetryStartNowDoesNothingWhenRecognizerIsAlreadyReady() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration()
    )

    recognizer.start()
    recognizer.retryStartNow()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(eventSource.startCount, 1)
  }

  func testRetryStartNowRetriesAfterStartFailure() {
    let eventSource = GestureEventSourceDouble(startResults: [false, true])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    recognizer.retryStartNow()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(eventSource.startCount, 2)
  }
}
