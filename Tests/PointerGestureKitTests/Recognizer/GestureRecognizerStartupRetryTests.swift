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

    XCTAssertEqual(
      eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)),
      .passThrough
    )
  }

  func testFailedStartWithoutRetryDelaysDoesNotRetryLater() async throws {
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
    try await Task.sleep(nanoseconds: 50_000_000)

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
    async throws
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

    try await Task.sleep(nanoseconds: 50_000_000)
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

  func testStopCancelsPendingRetry() async throws {
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

    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(eventSource.startCount, 1)
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

  func testInvalidOnlyEventSourceStartRetryDelaysDoNotScheduleRetry() async throws {
    let eventSource = GestureEventSourceDouble(startResults: [false, true])

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(eventSourceStartRetryDelays: [-1, .nan, .infinity])
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()
    try await Task.sleep(nanoseconds: 50_000_000)

    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .failed)
    XCTAssertEqual(
      recognizer.snapshot.status.lastFailure,
      GestureRecognizerFailure.eventSourceStartFailed
    )
    XCTAssertEqual(eventSource.startCount, 1)
  }

}
