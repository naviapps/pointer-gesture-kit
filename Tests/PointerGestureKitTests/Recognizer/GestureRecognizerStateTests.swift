import XCTest

import PointerGestureKit

final class GestureRecognizerStateTests: XCTestCase {
  @MainActor
  func testSnapshotExposesObservableStateToClients() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<String> =
      makeGestureRecognizerTestConfiguration()

    let recognizer = GestureRecognizer<String>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.isRecordingModeEnabled = true
    recognizer.start()

    let state = recognizer.snapshot
    XCTAssertEqual(state.status.lifecycle, .ready)
    XCTAssertFalse(state.status.isCapturingGesture)
    XCTAssertTrue(state.status.isRecordingModeEnabled)
    XCTAssertTrue(state.status.lastRecordedDirections.isEmpty)
    XCTAssertNil(state.status.lastFailure)
    XCTAssertFalse(state.trace.isVisible)
    XCTAssertTrue(state.trace.rawPoints.isEmpty)
    XCTAssertTrue(state.trace.directions.isEmpty)
    XCTAssertTrue(state.trace.directionEndpoints.isEmpty)
  }

  @MainActor
  func testSnapshotDefaultsToIdleObservableState() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<String> =
      makeGestureRecognizerTestConfiguration()

    let recognizer = GestureRecognizer<String>(
      eventSource: eventSource,
      configuration: configuration
    )

    let state = recognizer.snapshot
    XCTAssertEqual(state.status.lifecycle, .idle)
    XCTAssertFalse(state.status.isCapturingGesture)
    XCTAssertFalse(state.status.isRecordingModeEnabled)
    XCTAssertTrue(state.status.lastRecordedDirections.isEmpty)
    XCTAssertNil(state.status.lastFailure)
    XCTAssertFalse(state.trace.isVisible)
    XCTAssertTrue(state.trace.rawPoints.isEmpty)
    XCTAssertTrue(state.trace.directions.isEmpty)
    XCTAssertTrue(state.trace.directionEndpoints.isEmpty)
  }

  @MainActor
  func testRecognizerStateAndFailureAreSendableValues() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<String> =
      makeGestureRecognizerTestConfiguration()

    let recognizer = GestureRecognizer<String>(
      eventSource: eventSource,
      configuration: configuration
    )

    let state = recognizer.snapshot
    assertSendable(state)
    assertSendable(state.status)
    assertSendable(state.trace)
    assertSendable(GestureRecognizerState.Status.Lifecycle.ready)
    assertSendable(GestureRecognizerFailure.modifiersNotSatisfied)
  }

  @MainActor
  func testRecognizerStateLifecycleAndFailureAreEquatableValues() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<String> =
      makeGestureRecognizerTestConfiguration()

    let recognizer = GestureRecognizer<String>(
      eventSource: eventSource,
      configuration: configuration
    )

    let state = recognizer.snapshot
    XCTAssertEqual(state, state)
    XCTAssertEqual(state.status, state.status)
    XCTAssertEqual(state.trace, state.trace)
    XCTAssertNotEqual(GestureRecognizerState.Status.Lifecycle.idle, .ready)
    XCTAssertNotEqual(GestureRecognizerFailure.eventSourceStartFailed, .gestureSessionExpired)
  }

  func testTraceInitializerPreservesProvidedGeometry() {
    let rawPoints = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 20, y: 0),
      GesturePoint(x: 20, y: 20),
    ]

    let trimmedTrace = GestureRecognizerState.Trace(
      rawPoints: rawPoints,
      directions: [.right, .down],
      directionEndpoints: rawPoints,
      tailPoint: rawPoints[3]
    )
    let paddedTrace = GestureRecognizerState.Trace(
      rawPoints: rawPoints,
      directions: [.right, .down],
      directionEndpoints: [rawPoints[0]],
      tailPoint: GesturePoint(x: 30, y: 20)
    )

    XCTAssertEqual(trimmedTrace.directionEndpoints, rawPoints)
    XCTAssertEqual(trimmedTrace.tailPoint, rawPoints[3])
    XCTAssertEqual(paddedTrace.directionEndpoints, [rawPoints[0]])
    XCTAssertEqual(paddedTrace.tailPoint, GesturePoint(x: 30, y: 20))
  }

}
