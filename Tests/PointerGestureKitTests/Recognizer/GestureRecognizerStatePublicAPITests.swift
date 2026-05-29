import XCTest

import PointerGestureKit

final class GestureRecognizerStatePublicAPITests: XCTestCase {
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

  func testRecognizerStateLifecycleAndFailureAreHashableValues() {
    let status = GestureRecognizerState.Status(
      lifecycle: .ready,
      isCapturingGesture: true,
      isRecordingModeEnabled: true,
      lastRecordedDirections: [.right],
      lastFailure: .modifiersNotSatisfied
    )
    let trace = GestureRecognizerState.Trace(
      isVisible: true,
      rawPoints: [.init(x: 0, y: 0), .init(x: 12, y: 0)],
      directions: [.right],
      directionEndpoints: [.init(x: 0, y: 0), .init(x: 12, y: 0)]
    )
    let state = GestureRecognizerState(status: status, trace: trace)

    XCTAssertEqual(
      Set([
        GestureRecognizerState.Status.Lifecycle.idle,
        .starting,
        .ready,
        .retrying,
        .failed,
        .ready,
      ]).count,
      5
    )
    XCTAssertEqual(
      Set([
        GestureRecognizerFailure.eventSourceStartFailed,
        .recognitionDisabled,
        .modifiersNotSatisfied,
        .gestureSessionExpired,
        .gestureSessionExpired,
      ]).count,
      4
    )
    XCTAssertEqual(Set([status, status]).count, 1)
    XCTAssertEqual(Set([trace, trace]).count, 1)
    XCTAssertEqual(Set([state, state]).count, 1)
  }

  func testRecognizerStateAndFailureAreSendableValues() {
    assertSendable(GestureRecognizerState())
    assertSendable(GestureRecognizerState.Status())
    assertSendable(GestureRecognizerState.Trace())
    assertSendable(GestureRecognizerState.Status.Lifecycle.ready)
    assertSendable(GestureRecognizerFailure.modifiersNotSatisfied)
  }

  func testRecognizerStateCanBeConstructedByClients() {
    let status = GestureRecognizerState.Status(
      lifecycle: .idle,
      isCapturingGesture: false,
      isRecordingModeEnabled: true,
      lastRecordedDirections: [.right],
      lastFailure: .gestureSessionExpired
    )
    let trace = GestureRecognizerState.Trace(
      isVisible: true,
      rawPoints: [.init(x: 0, y: 0), .init(x: 12, y: 0)],
      directions: [.right],
      directionEndpoints: [.init(x: 0, y: 0), .init(x: 12, y: 0)]
    )
    let state = GestureRecognizerState(status: status, trace: trace)

    XCTAssertEqual(state.status.lifecycle, .idle)
    XCTAssertFalse(state.status.isCapturingGesture)
    XCTAssertTrue(state.status.isRecordingModeEnabled)
    XCTAssertEqual(state.status.lastRecordedDirections, [.right])
    XCTAssertEqual(state.status.lastFailure, .gestureSessionExpired)
    XCTAssertTrue(state.trace.isVisible)
    XCTAssertEqual(state.trace.rawPoints, [.init(x: 0, y: 0), .init(x: 12, y: 0)])
    XCTAssertEqual(state.trace.directions, [.right])
    XCTAssertEqual(state.trace.directionEndpoints, [.init(x: 0, y: 0), .init(x: 12, y: 0)])
  }

  func testRecognizerTraceNormalizesDirectionEndpointsForClientConstructedState() {
    let trace = GestureRecognizerState.Trace(
      isVisible: true,
      rawPoints: [.init(x: 0, y: 0), .init(x: 12, y: 0), .init(x: 12, y: 12)],
      directions: [.right, .down],
      directionEndpoints: [.init(x: 0, y: 0)]
    )

    XCTAssertEqual(
      trace.directionEndpoints,
      [.init(x: 0, y: 0), .init(x: 12, y: 0), .init(x: 12, y: 12)]
    )
  }

  func testRecognizerTraceTrimsExcessDirectionEndpointsForClientConstructedState() {
    let trace = GestureRecognizerState.Trace(
      isVisible: true,
      rawPoints: [
        .init(x: 0, y: 0),
        .init(x: 12, y: 0),
        .init(x: 24, y: 0),
        .init(x: 24, y: 12),
      ],
      directions: [.right],
      directionEndpoints: [
        .init(x: 0, y: 0),
        .init(x: 12, y: 0),
        .init(x: 24, y: 0),
        .init(x: 24, y: 12),
      ]
    )

    XCTAssertEqual(
      trace.directionEndpoints,
      [.init(x: 0, y: 0), .init(x: 24, y: 12)]
    )
  }

  func testRecognizerStateProvidesEmptyDefaults() {
    let state = GestureRecognizerState()

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

  func testRecognizerStateAndFailureDoNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureRecognizerState.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerState.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerState.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerState.self is any Error.Type)
    XCTAssertFalse(GestureRecognizerState.Status.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerState.Status.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerState.Status.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerState.Status.self is any Error.Type)
    XCTAssertFalse(GestureRecognizerState.Trace.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerState.Trace.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerState.Trace.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerState.Trace.self is any Error.Type)
    XCTAssertFalse(GestureRecognizerState.Status.Lifecycle.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerState.Status.Lifecycle.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerState.Status.Lifecycle.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerState.Status.Lifecycle.self is any Error.Type)
    XCTAssertFalse(GestureRecognizerFailure.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerFailure.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerFailure.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerFailure.self is any Error.Type)
  }
}
