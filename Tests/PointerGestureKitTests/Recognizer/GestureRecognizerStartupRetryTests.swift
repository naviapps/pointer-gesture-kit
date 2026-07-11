import Foundation
import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerStartupRetryTests: XCTestCase {
  func testStartTransitionsToFailedWhenEventSourceFailsAndNoRetryDelays() {
    let eventSource = GestureEventSourceDouble(startResult: false)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .failed)
    XCTAssertEqual(
      recognizer.snapshot.status.lastFailure,
      GestureRecognizerFailure.eventSourceStartFailed
    )
    XCTAssertEqual(eventSource.startCount, 1)
  }

  func testFailedStartDoesNotInstallEventHandler() {
    let eventSource = GestureEventSourceDouble(startResult: false)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .passThrough
    )
  }

  func testFailedStartWithoutRetryDelaysDoesNotRetryLater() async {
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

    await XCTAssertNotEventually(timeout: 0.05) {
      eventSource.startCount > 1
    }

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .failed)
    XCTAssertEqual(
      recognizer.snapshot.status.lastFailure,
      GestureRecognizerFailure.eventSourceStartFailed
    )
    XCTAssertEqual(eventSource.startCount, 1)
  }

  func testScheduledRetryEventuallyEnablesRecognizerAfterTransientStartFailure() async {
    let eventSource = GestureEventSourceDouble(startResults: [false, true])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(eventSourceStartRetryDelays: [0])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    await XCTAssertEventually(timeout: 1) {
      recognizer.snapshot.status.lifecycle == .ready
        && recognizer.snapshot.status.lastFailure == nil
    }

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(eventSource.startCount, 2)
  }

  func testScheduledRetryKeepsRetryingAfterRepeatedStartFailures() async {
    let eventSource = GestureEventSourceDouble(startResults: [false, false, false])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [0.01])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    await XCTAssertEventually(timeout: 1) {
      eventSource.startCount >= 3
    }

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .retrying)
    XCTAssertEqual(
      recognizer.snapshot.status.lastFailure,
      GestureRecognizerFailure.eventSourceStartFailed
    )
    XCTAssertGreaterThanOrEqual(eventSource.startCount, 3)

    recognizer.stop()
  }

  func testCallingStartAgainCancelsPendingRetryAndRetriesImmediatelyAfterStartFailure()
    async
  {
    let eventSource = GestureEventSourceDouble(startResults: [false, true])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [0.01])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    recognizer.start()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(eventSource.startCount, 2)

    await XCTAssertNotEventually(timeout: 0.05) {
      eventSource.startCount > 2
    }
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertEqual(eventSource.startCount, 2)
  }

  func testCallingStartAgainRetriesAfterFailedStartWithoutRetryDelays() {
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
    recognizer.start()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(eventSource.startCount, 2)
  }

  func testStopCancelsPendingRetry() async {
    let eventSource = GestureEventSourceDouble(startResults: [false, true])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [0.01])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    XCTAssertEqual(eventSource.startCount, 1)

    recognizer.stop()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .idle)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertEqual(eventSource.stopCount, 1)

    await XCTAssertNotEventually(timeout: 0.05) {
      eventSource.startCount > 1
    }
    XCTAssertEqual(eventSource.startCount, 1)
  }

  func testReleaseWhileStartupRetryIsPendingDoesNotRetainRecognizer() async {
    let eventSource = GestureEventSourceDouble(startResult: false)
    weak var weakRecognizer: GestureRecognizer<UUID>?
    var recognizer: GestureRecognizer<UUID>? = GestureRecognizer(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [0.01])
      )
    )
    weakRecognizer = recognizer

    recognizer?.start()
    await XCTAssertEventually(timeout: 1) {
      eventSource.startCount >= 2
    }

    recognizer = nil

    await XCTAssertEventually(timeout: 1) {
      weakRecognizer == nil && eventSource.stopCount == 1
    }
    XCTAssertNil(weakRecognizer)
    XCTAssertEqual(eventSource.stopCount, 1)
  }

  func testHugeFiniteEventSourceStartRetryDelayCanBeScheduled() async {
    let eventSource = GestureEventSourceDouble(startResults: [false, true])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [.greatestFiniteMagnitude])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    await Task.yield()

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .retrying)
    XCTAssertEqual(
      recognizer.snapshot.status.lastFailure,
      GestureRecognizerFailure.eventSourceStartFailed
    )
    XCTAssertEqual(eventSource.startCount, 1)
  }

}
