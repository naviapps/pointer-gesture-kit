import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerObservationFilteringTests: XCTestCase {
  func testObserveStatusSkipsTraceOnlyUpdates() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 0, y: 0)))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    var statuses: [GestureRecognizerState.Status] = []
    let token = recognizer.observeStatus { status in
      statuses.append(status)
    }
    XCTAssertEqual(statuses.count, 1)

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 80))
    )
    XCTAssertEqual(recognizer.snapshot.trace.directions.last, .down)
    XCTAssertEqual(
      recognizer.snapshot.trace.directionEndpoints,
      [.init(x: 0, y: 0), .init(x: 40, y: 0), .init(x: 40, y: 80)]
    )

    await XCTAssertNotEventually(timeout: 0.05) { statuses.count > 1 }
    XCTAssertEqual(statuses.count, 1)

    _ = token
  }

  func testObserveStatusEmitsRecordingModeChanges() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var statuses: [GestureRecognizerState.Status] = []
    let token = recognizer.observeStatus { status in
      statuses.append(status)
    }
    XCTAssertEqual(statuses.map(\.isRecordingModeEnabled), [false])

    recognizer.isRecordingModeEnabled = true
    await XCTAssertEventually(timeout: 0.2) { statuses.count >= 2 }

    XCTAssertEqual(statuses.map(\.isRecordingModeEnabled), [false, true])

    _ = token
  }

  func testObserveStatusEmitsFailureChanges() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        areModifiersSatisfied: { _, _ in false },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var statuses: [GestureRecognizerState.Status] = []
    let token = recognizer.observeStatus { status in
      statuses.append(status)
    }
    XCTAssertEqual(statuses.map(\.lastFailure), [nil])

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 0, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      statuses.contains { $0.lastFailure == .modifiersNotSatisfied }
    }
    XCTAssertEqual(statuses.map(\.lastFailure), [nil, .modifiersNotSatisfied])

    _ = token
  }

  func testObserveTraceSkipsStatusOnlyUpdates() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }
    XCTAssertEqual(traces.count, 1)

    recognizer.start()
    XCTAssertEqual(recognizer.snapshot.status.lifecycle, .ready)

    await XCTAssertNotEventually(timeout: 0.05) { traces.count > 1 }
    XCTAssertEqual(traces.count, 1)

    _ = token
  }

  func testObserveTraceEmitsTraceChanges() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }
    XCTAssertEqual(traces.map(\.directions), [[]])

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 0, y: 0)))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) { traces.contains { $0.directions == [.right] } }

    XCTAssertEqual(traces.map(\.directions), [[], [.right]])
    XCTAssertEqual(traces.last?.directionEndpoints, [.init(x: 0, y: 0), .init(x: 40, y: 0)])

    _ = token
  }

  func testObserveTraceEmitsSameDirectionEndpointUpdatesImmediately() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.last?.directionEndpoints == [.zero, .init(x: 10, y: 0)]
    }
    let traceCountAfterFirstDirection = traces.count

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.count > traceCountAfterFirstDirection
        && traces.last?.directionEndpoints == [.zero, .init(x: 20, y: 0)]
        && traces.last?.tailPoint == .init(x: 20, y: 0)
    }
    XCTAssertEqual(traces.last?.rawPoints, [.zero, .init(x: 10, y: 0)])

    _ = token
  }

  func testObserveTracePublishesTailPointWhenVisibleTurnHasNotReachedDirectionThreshold() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 25
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero))
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.last?.directionEndpoints == [.zero, .init(x: 40, y: 0)]
    }
    let traceCountAfterFirstDirection = traces.count

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 45, y: 10))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.count > traceCountAfterFirstDirection
        && traces.last?.rawPoints == [.zero, .init(x: 40, y: 0)]
        && traces.last?.directionEndpoints == [.zero, .init(x: 40, y: 0)]
        && traces.last?.tailPoint == .init(x: 45, y: 10)
    }

    _ = token
  }

  func testObserveTraceEmitsVisibleTraceDuringRapidGestureCompletion() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertTrue(
      traces.contains { $0.isVisible && $0.directions == [.right] },
      "Recording overlays should not wait for the next main-actor turn before drawing fast input."
    )

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertGreaterThanOrEqual(traces.count, 3)
    XCTAssertEqual(traces.last?.isVisible, false)

    XCTAssertTrue(
      traces.contains { !$0.isVisible && $0.directions.isEmpty },
      "Trace observation should still return to hidden after the rapid gesture completes."
    )

    _ = token
  }

  func testRegisteredPrefixTraceVisibilityIsDeliveredWithoutMainActorYield() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertTrue(
      traces.last?.isVisible == true && traces.last?.directions == [.right],
      "Registered prefixes should be available to the overlay before another main-actor turn."
    )

    let traceCountBeforeFinish = traces.count
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertTrue(
      traces.count > traceCountBeforeFinish && traces.last?.isVisible == false
    )

    _ = token
  }

  func testExactMatchTraceVisibilityIsDeliveredWithoutMainActorYield() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertTrue(
      traces.last?.isVisible == true && traces.last?.directions == [.right],
      "Exact matches should be available to the overlay before another main-actor turn."
    )

    _ = token
  }

  func testObserveTracePublishesVisibleTailUpdatesWithoutWaitingForMainActorYield() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.last?.isVisible == true && traces.last?.tailPoint == .init(x: 10, y: 0)
    }
    let visibleTraceCountBeforeTailUpdates = traces.filter(\.isVisible).count

    for x in [20.0, 30.0, 40.0] {
      _ = eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: x, y: 0))
      )
    }

    let visibleTraces = traces.filter(\.isVisible)
    XCTAssertEqual(
      Array(visibleTraces.dropFirst(visibleTraceCountBeforeTailUpdates).map(\.tailPoint)),
      [
        .init(x: 20, y: 0),
        .init(x: 30, y: 0),
        .init(x: 40, y: 0),
      ],
      "Visible trace updates should keep pace with pointer movement before overlay rendering."
    )
    XCTAssertEqual(
      Array(visibleTraces.dropFirst(visibleTraceCountBeforeTailUpdates).map(\.directions)),
      [[.right], [.right], [.right]]
    )

    _ = token
  }

  func testCancelingTraceObservationDuringLowLatencyNotificationDoesNotInterruptDelivery() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var firstToken: GestureObservationToken?
    var firstTraces: [GestureRecognizerState.Trace] = []
    var secondTraces: [GestureRecognizerState.Trace] = []

    firstToken = recognizer.observeTrace { trace in
      firstTraces.append(trace)
      if trace.isVisible {
        firstToken?.cancel()
      }
    }
    let secondToken = recognizer.observeTrace { trace in
      secondTraces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 0))
    )

    XCTAssertTrue(firstTraces.contains { $0.isVisible && $0.directions == [.right] })
    XCTAssertTrue(secondTraces.contains { $0.isVisible && $0.directions == [.right] })

    let firstTraceCountAfterCancel = firstTraces.count
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      secondTraces.last?.tailPoint == .init(x: 20, y: 0)
    }
    await XCTAssertNotEventually(timeout: 0.05) {
      firstTraces.count > firstTraceCountAfterCancel
    }

    XCTAssertEqual(firstTraces.count, firstTraceCountAfterCancel)

    _ = secondToken
  }

  func testCancelingAnotherTraceObservationDuringLowLatencyNotificationDoesNotInterruptDelivery()
    async
  {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var secondToken: GestureObservationToken?
    var firstTraces: [GestureRecognizerState.Trace] = []
    var secondTraces: [GestureRecognizerState.Trace] = []

    let firstToken = recognizer.observeTrace { trace in
      firstTraces.append(trace)
      if trace.isVisible {
        secondToken?.cancel()
      }
    }
    secondToken = recognizer.observeTrace { trace in
      secondTraces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 10, y: 0))
    )

    XCTAssertTrue(firstTraces.contains { $0.isVisible && $0.directions == [.right] })
    XCTAssertTrue(secondTraces.contains { $0.isVisible && $0.directions == [.right] })

    let secondTraceCountAfterCancel = secondTraces.count
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      firstTraces.last?.tailPoint == .init(x: 20, y: 0)
    }
    await XCTAssertNotEventually(timeout: 0.05) {
      secondTraces.count > secondTraceCountAfterCancel
    }

    XCTAssertEqual(secondTraces.count, secondTraceCountAfterCancel)

    _ = firstToken
    _ = secondToken
  }

  func testObserveTraceHidesImmediatelyAfterRegisteredPrefixMismatch() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )
    XCTAssertTrue(traces.last?.isVisible == true && traces.last?.directions == [.right])

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: -40))
    )

    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)

    XCTAssertEqual(traces.map(\.isVisible), [false, true, false])

    _ = token
  }

  func testObserveTraceShowsRegisteredPrefixBeforeExactMatch() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right, .down], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right])
    XCTAssertTrue(recognizer.snapshot.trace.isVisible)
    await XCTAssertEventually(timeout: 0.2) {
      traces.contains { $0.isVisible && $0.directions == [.right] }
    }

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 40))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.contains { $0.isVisible && $0.directions == [.right, .down] }
    }

    _ = token
  }

  func testObserveTraceReturnsToHiddenAfterVisibleExactMatchMismatch() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.contains { $0.isVisible && $0.directions == [.right] }
    }
    let traceCountAfterVisibleMatch = traces.count

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 40))
    )

    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
    XCTAssertTrue(recognizer.snapshot.trace.directions.isEmpty)

    await XCTAssertEventually(timeout: 0.2) {
      traces.count > traceCountAfterVisibleMatch
        && traces.last?.isVisible == false
        && traces.last?.directions.isEmpty == true
    }

    _ = token
  }

  func testObserveTraceKeepsVisibleWhenMatchContinuesIntoRegisteredPrefix() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        makeMatcher: { _ in
          var matcher = GesturePatternMatcher<UUID>()
          matcher.register(pattern: [.right], match: UUID())
          matcher.register(pattern: [.right, .down, .left], match: UUID())
          return matcher
        },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )
    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    var traces: [GestureRecognizerState.Trace] = []
    let token = recognizer.observeTrace { trace in
      traces.append(trace)
    }

    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.contains { $0.isVisible && $0.directions == [.right] }
    }
    let traceCountAfterVisibleMatch = traces.count

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 40))
    )

    XCTAssertEqual(recognizer.snapshot.trace.directions, [.right, .down])
    XCTAssertTrue(recognizer.snapshot.trace.isVisible)
    await XCTAssertEventually(timeout: 0.2) {
      traces.count > traceCountAfterVisibleMatch
        && traces.last?.isVisible == true
        && traces.last?.directions == [.right, .down]
    }

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 0, y: 40))
    )

    await XCTAssertEventually(timeout: 0.2) {
      traces.contains { $0.isVisible && $0.directions == [.right, .down, .left] }
    }

    _ = token
  }

  func testDeferredTraceVisibilityNotificationsDoNotReplayToNewObservers() async {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let recognizer = makeRecognizer(eventSource: eventSource)

    var firstObserverTraces: [GestureRecognizerState.Trace] = []
    let firstToken = recognizer.observeTrace { trace in
      firstObserverTraces.append(trace)
    }

    recognizer.isRecordingModeEnabled = true
    recognizer.start()
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .zero)
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 40, y: 0))
    )
    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 40, y: 0))
    )

    var secondObserverTraces: [GestureRecognizerState.Trace] = []
    let secondToken = recognizer.observeTrace { trace in
      secondObserverTraces.append(trace)
    }

    await XCTAssertNotEventually(timeout: 0.05) {
      secondObserverTraces.contains { $0.isVisible }
    }
    XCTAssertEqual(secondObserverTraces.map(\.isVisible), [false])

    _ = firstObserverTraces
    _ = firstToken
    _ = secondToken
  }

  private func makeRecognizer(eventSource: GestureEventSourceDouble) -> GestureRecognizer<UUID> {
    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    return GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )
  }
}
