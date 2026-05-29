import PointerGestureKit
import XCTest

final class GestureRecognizerTuningTests: XCTestCase {
  func testInitializerPreservesValidCustomValues() {
    let tuning = GestureRecognizerTuning(
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

  func testMaximumRawPointCountIsAtLeastOne() {
    XCTAssertEqual(
      GestureRecognizerTuning(maximumRawPointCount: 0).maximumRawPointCount, 1)
    XCTAssertEqual(
      GestureRecognizerTuning(maximumRawPointCount: -10).maximumRawPointCount, 1)
  }

  func testEventSourceStartRetryDelaysDiscardInvalidValuesAndPreserveExplicitZero() {
    let tuning = GestureRecognizerTuning(
      eventSourceStartRetryDelays: [-1, .nan, .infinity, 0, 0.25]
    )

    XCTAssertEqual(tuning.eventSourceStartRetryDelays, [0, 0.25])
  }

  func testInvalidOnlyEventSourceStartRetryDelaysBecomeEmpty() {
    let tuning = GestureRecognizerTuning(
      eventSourceStartRetryDelays: [-1, .nan, .infinity]
    )

    XCTAssertTrue(tuning.eventSourceStartRetryDelays.isEmpty)
  }

  func testEmptyEventSourceStartRetryDelaysArePreserved() {
    let tuning = GestureRecognizerTuning(eventSourceStartRetryDelays: [])

    XCTAssertTrue(tuning.eventSourceStartRetryDelays.isEmpty)
  }

  func testRecognitionAxisDistancesAreNonNegativeAndFinite() {
    let tuning = GestureRecognizerTuning(
      minimumGestureStartAxisDistance: -.infinity,
      minimumDirectionChangeAxisDistance: .nan,
      maximumGestureSessionDuration: -1
    )

    XCTAssertEqual(tuning.minimumGestureStartAxisDistance, 0)
    XCTAssertEqual(tuning.minimumDirectionChangeAxisDistance, 0)
    XCTAssertNil(tuning.maximumGestureSessionDuration)
  }

  func testRecognitionAxisDistancesRejectNegativeValues() {
    let tuning = GestureRecognizerTuning(
      minimumGestureStartAxisDistance: -1,
      minimumDirectionChangeAxisDistance: -2
    )

    XCTAssertEqual(tuning.minimumGestureStartAxisDistance, 0)
    XCTAssertEqual(tuning.minimumDirectionChangeAxisDistance, 0)
  }

  func testMaximumGestureSessionDurationKeepsPositiveFiniteValue() {
    let tuning = GestureRecognizerTuning(maximumGestureSessionDuration: 1.25)

    XCTAssertEqual(tuning.maximumGestureSessionDuration, 1.25)
  }

  func testMaximumGestureSessionDurationRejectsNonPositiveAndNonFiniteValues() {
    XCTAssertNil(
      GestureRecognizerTuning(maximumGestureSessionDuration: -1)
        .maximumGestureSessionDuration)
    XCTAssertNil(
      GestureRecognizerTuning(maximumGestureSessionDuration: 0)
        .maximumGestureSessionDuration)
    XCTAssertNil(
      GestureRecognizerTuning(maximumGestureSessionDuration: .nan)
        .maximumGestureSessionDuration)
    XCTAssertNil(
      GestureRecognizerTuning(maximumGestureSessionDuration: .infinity)
        .maximumGestureSessionDuration)
  }

  func testDefaultTuningValuesAreStable() {
    let tuning = GestureRecognizerTuning()

    XCTAssertEqual(tuning.minimumGestureStartAxisDistance, 10)
    XCTAssertEqual(tuning.minimumDirectionChangeAxisDistance, 25)
    XCTAssertEqual(tuning.maximumGestureSessionDuration, 10)
    XCTAssertEqual(tuning.maximumRawPointCount, 1000)
    XCTAssertEqual(tuning.eventSourceStartRetryDelays, [0.25, 0.5, 1, 2, 4])
  }

  func testTuningDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureRecognizerTuning.self is any Codable.Type)
    XCTAssertFalse(GestureRecognizerTuning.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognizerTuning.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognizerTuning.self is any Error.Type)
  }

  func testTuningIsHashableValue() {
    let tuning = GestureRecognizerTuning(
      minimumGestureStartAxisDistance: 1,
      minimumDirectionChangeAxisDistance: 2,
      maximumGestureSessionDuration: 3,
      maximumRawPointCount: 4,
      eventSourceStartRetryDelays: [5]
    )

    XCTAssertEqual(Set([tuning, tuning]).count, 1)
  }

  func testTuningIsSendableValue() {
    assertSendable(GestureRecognizerTuning())
  }
}
