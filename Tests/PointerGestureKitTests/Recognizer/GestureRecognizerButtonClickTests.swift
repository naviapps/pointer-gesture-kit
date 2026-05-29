import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerButtonClickTests: XCTestCase {
  func testMovedPendingButtonInputRequestsSequenceReplayWithoutStartingGesture() {
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

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 28, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 28, y: 10))
      ),
      .consume
    )

    XCTAssertEqual(
      replayRequests,
      [.drag(button: .secondary, points: [.init(x: 10, y: 10), .init(x: 28, y: 10)])]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
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

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    XCTAssertTrue(replayRequests.isEmpty)

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
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

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 12, y: 11))
      ),
      .consume
    )
    XCTAssertEqual(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
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

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
      ),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 20, y: 0))
      ),
      .consume
    )

    XCTAssertTrue(recognizer.snapshot.trace.isVisible)
    XCTAssertEqual(recognizer.snapshot.trace.rawPoints, [.init(x: 20, y: 0)])
  }

  func testRepeatedButtonDownKeepsPendingButtonInputPoint() {
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

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
      ),
      .consume
    )
    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 20, y: 20))
      ),
      .consume
    )

    XCTAssertEqual(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 20))
      ),
      .consume
    )

    XCTAssertEqual(replayRequests, [.click(button: .secondary, at: .init(x: 10, y: 10))])
    XCTAssertEqual(recognitionContextRequestCount, 1)
  }
}
