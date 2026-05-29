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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 40, y: 0))
    )

    var statuses: [GestureRecognizerState.Status] = []
    let token = recognizer.observeStatus { status in
      statuses.append(status)
    }
    XCTAssertEqual(statuses.count, 1)

    _ = eventSource.send(
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 40, y: 80))
    )
    XCTAssertEqual(recognizer.snapshot.trace.directions.last, .down)

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
      makeGestureInputEvent(kind: .buttonDragged(.secondary), location: .init(x: 40, y: 0))
    )

    await XCTAssertEventually(timeout: 0.2) { traces.contains { $0.directions == [.right] } }

    XCTAssertEqual(traces.map(\.directions), [[], [.right]])

    _ = token
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
