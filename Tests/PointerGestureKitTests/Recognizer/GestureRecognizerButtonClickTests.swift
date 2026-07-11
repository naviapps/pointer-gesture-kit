import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerButtonClickTests: XCTestCase {
  func testMovedPendingButtonInputBelowStartDistanceRequestsClickReplayForContextMenu() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 25
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 19, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 19, y: 10))
      ),
      .consume
    )

    assertReplayRequests(
      replayRequests,
      [.click(button: .secondary, at: .init(x: 10, y: 10))]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testMovementAtMinimumStartDistanceStartsRecognizedGesture() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 0))
      ),
      .consume
    )

    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertTrue(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])
    XCTAssertEqual(recognizer.snapshot.trace.directionEndpoints, [.zero, .init(x: 10, y: 0)])
  }

  func testPlainButtonClickRequestsClickReplayAtStartPoint() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 25
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    XCTAssertTrue(replayRequests.isEmpty)

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    assertReplayRequests(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testPlainButtonClickWithMovedButtonUpRequestsClickReplayAtStartPoint() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 25
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 12, y: 11))
      ),
      .consume
    )
    assertReplayRequests(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testTraceVisibilityUsesSessionStartPointAfterRawPointBufferTrim() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 10,
          minimumDirectionChangeAxisDistance: 0,
          maximumRawPointCount: 1
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0))
      ),
      .consume
    )

    XCTAssertTrue(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(recognizer.snapshot.trace.rawPoints, [.init(x: 20, y: 0)])
    XCTAssertEqual(recognizer.snapshot.trace.directionEndpoints, [.zero, .init(x: 20, y: 0)])
  }

  func testRepeatedButtonDownReplaysPendingInputAndStartsNewInput() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []
    var recognitionContextRequestCount = 0

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        recognitionContext: { _ in
          recognitionContextRequestCount += 1
          return nil
        },
        areModifiersSatisfied: { _, _ in true }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 20, y: 20))
      ),
      .consume
    )

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 20))
      ),
      .consume
    )

    assertReplayRequests(
      replayRequests,
      [
        .click(button: .secondary, at: .init(x: 10, y: 10)),
        .click(button: .secondary, at: .init(x: 20, y: 20)),
      ]
    )
    XCTAssertEqual(recognitionContextRequestCount, 2)
  }

  func testRepeatedButtonDownReleasesActiveSessionAndStartsNewInput() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var replayRequests: [GestureReplayRequest] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { replayRequests.append($0) },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 100
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )
    recognizer.isRecordingModeEnabled = true
    recognizer.start()

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 10))
    )
    XCTAssertTrue(recognizer.snapshot.status.isCapturingGesture)

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 80, y: 80))
      ),
      .consume
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 80, y: 80))
      ),
      .consume
    )

    assertReplayRequests(
      replayRequests,
      [
        .release(button: .secondary, at: .init(x: 40, y: 10)),
        .click(button: .secondary, at: .init(x: 80, y: 80)),
      ]
    )
  }
}
