import PointerGestureKit
import XCTest

final class GestureRecognizerTuningTests: XCTestCase {
  func testValidatedPreservesCustomValues() throws {
    let tuning = try GestureRecognizerTuning.validated(
      minimumGestureStartAxisDistance: 1.5,
      minimumDirectionChangeAxisDistance: 2.5,
      maximumGestureSessionDuration: nil,
      maximumRawPointCount: 42,
      eventSourceStartRetryDelays: [0, 0.125, 3]
    )

    XCTAssertEqual(tuning.minimumGestureStartAxisDistance, 1.5)
    XCTAssertEqual(tuning.minimumDirectionChangeAxisDistance, 2.5)
    XCTAssertNil(tuning.maximumGestureSessionDuration)
    XCTAssertEqual(tuning.maximumRawPointCount, 42)
    XCTAssertEqual(tuning.eventSourceStartRetryDelays, [0, 0.125, 3])
  }

  func testValidatedRejectsInvalidDistances() {
    XCTAssertThrowsError(
      try GestureRecognizerTuning.validated(minimumGestureStartAxisDistance: -1)
    ) { error in
      XCTAssertEqual(
        error as? GestureRecognizerTuning.ValidationError,
        .invalidMinimumGestureStartAxisDistance
      )
    }
    XCTAssertThrowsError(
      try GestureRecognizerTuning.validated(minimumDirectionChangeAxisDistance: .nan)
    ) { error in
      XCTAssertEqual(
        error as? GestureRecognizerTuning.ValidationError,
        .invalidMinimumDirectionChangeAxisDistance
      )
    }
  }

  func testValidatedRejectsInvalidDurationAndPointCount() {
    XCTAssertThrowsError(
      try GestureRecognizerTuning.validated(maximumGestureSessionDuration: 0)
    ) { error in
      XCTAssertEqual(
        error as? GestureRecognizerTuning.ValidationError,
        .invalidMaximumGestureSessionDuration
      )
    }
    XCTAssertThrowsError(try GestureRecognizerTuning.validated(maximumRawPointCount: 0)) { error in
      XCTAssertEqual(
        error as? GestureRecognizerTuning.ValidationError,
        .invalidMaximumRawPointCount
      )
    }
  }

  func testValidatedReportsInvalidRetryDelayIndex() {
    XCTAssertThrowsError(
      try GestureRecognizerTuning.validated(eventSourceStartRetryDelays: [0.1, .infinity])
    ) { error in
      XCTAssertEqual(
        error as? GestureRecognizerTuning.ValidationError,
        .invalidEventSourceStartRetryDelay(index: 1)
      )
    }
  }

  func testValidatedPreservesRetryOrderDuplicatesAndZero() throws {
    let tuning = try GestureRecognizerTuning.validated(
      eventSourceStartRetryDelays: [1, 0.25, 1, 0]
    )
    XCTAssertEqual(tuning.eventSourceStartRetryDelays, [1, 0.25, 1, 0])
  }

  func testStandardValuesAreExpected() {
    let tuning = GestureRecognizerTuning.standard
    XCTAssertEqual(tuning.minimumGestureStartAxisDistance, 10)
    XCTAssertEqual(tuning.minimumDirectionChangeAxisDistance, 25)
    XCTAssertEqual(tuning.maximumGestureSessionDuration, 1)
    XCTAssertEqual(tuning.maximumRawPointCount, 256)
    XCTAssertEqual(tuning.eventSourceStartRetryDelays, [0.25, 0.5, 1, 2, 4])
  }

  func testTuningIsEquatableAndSendable() throws {
    let tuning = try GestureRecognizerTuning.validated(maximumGestureSessionDuration: nil)
    assertSendable(tuning)
    assertSendable(GestureRecognizerTuning.ValidationError.invalidMaximumRawPointCount)
    XCTAssertEqual(tuning, tuning)
  }

  @MainActor
  func testUpdateTuningAppliesToFutureGestureSessions() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var matcher = GesturePatternMatcher<UUID>()
    matcher.register(pattern: [.right], match: UUID())
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in matcher },
        tuning: .testing(
          minimumGestureStartAxisDistance: 100,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    )

    recognizer.start()
    _ = eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 50, y: 0)))
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    recognizer.cancelActiveGesture()
    recognizer.updateTuning(
      .testing(
        minimumGestureStartAxisDistance: 10,
        minimumDirectionChangeAxisDistance: 0
      ))
    _ = eventSource.send(makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 50, y: 0)))

    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])
  }

  @MainActor
  func testUpdateTuningReportsWhetherTuningChanged() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let initialTuning = GestureRecognizerTuning.testing(
      minimumGestureStartAxisDistance: 100,
      minimumDirectionChangeAxisDistance: 0
    )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: makeGestureRecognizerTestConfiguration(tuning: initialTuning)
    )

    XCTAssertFalse(recognizer.updateTuning(initialTuning))
    XCTAssertTrue(
      recognizer.updateTuning(
        .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 0
        )))
  }
}
