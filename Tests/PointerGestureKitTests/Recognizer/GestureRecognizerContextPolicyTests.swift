import XCTest

import PointerGestureKit

@MainActor
final class GestureRecognizerContextPolicyTests: XCTestCase {
  func testGestureStartUsesPointRecognitionContextWhenAvailable() throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: "point-context"))
    var requestedLocations: [GesturePoint] = []
    var requestedContexts: [GestureRecognitionContext?] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        recognitionContext: { location in
          requestedLocations.append(location)
          return context
        },
        areModifiersSatisfied: { _, context in
          requestedContexts.append(context)
          return true
        }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let down = makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    _ = eventSource.send(down)

    XCTAssertEqual(requestedContexts, [context])
    XCTAssertEqual(requestedLocations, [.init(x: 10, y: 10)])
  }

  func testPendingButtonInputUsesStartContextWhenCurrentContextChanges() throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let disabledContext = try XCTUnwrap(GestureRecognitionContext(identifier: "disabled-context"))

    let currentContext = MutableRecognitionContext()
    var sequenceReplayRequests: [[GesturePoint]] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { request in
          if case let .dragStart(_, points) = request {
            sequenceReplayRequests.append(points)
          }
        },
        recognitionContext: { _ in currentContext.value },
        isRecognitionEnabled: { active in
          active != disabledContext
        },
        areModifiersSatisfied: { _, _ in true },
        tuning: .testing(
          minimumGestureStartAxisDistance: 0,
          minimumDirectionChangeAxisDistance: 0
        )
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let down = makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    assertDisposition(eventSource.send(down), .consume)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)

    currentContext.value = disabledContext

    let drag = makeGestureInputEvent(
      kind: .buttonMoved(.secondary), location: .init(x: 100, y: 10))
    assertDisposition(eventSource.send(drag), .consume)

    let up = makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 120, y: 10))
    assertDisposition(eventSource.send(up), .passThrough)
    XCTAssertEqual(
      sequenceReplayRequests,
      [[.init(x: 10, y: 10), .init(x: 100, y: 10)]]
    )
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertFalse(recognizer.snapshot.trace.isVisible)
  }

  func testGestureStartPassesThroughWhenRecognitionIsDisabledForContext() throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let disabledContext = try XCTUnwrap(GestureRecognitionContext(identifier: "disabled-context"))

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        recognitionContext: { _ in disabledContext },
        isRecognitionEnabled: { context in
          context != disabledContext
        },
        areModifiersSatisfied: { _, _ in true }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let down = makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    let result = eventSource.send(down)

    assertDisposition(result, .passThrough)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .recognitionDisabled)
  }

  func testGestureStartPassesThroughWhenRecognitionIsDisabledWithoutContext() {
    let eventSource = GestureEventSourceDouble(startResult: true)

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        isRecognitionEnabled: { context in
          XCTAssertNil(context)
          return false
        },
        areModifiersSatisfied: { _, _ in true }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let result = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )

    assertDisposition(result, .passThrough)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .recognitionDisabled)
  }

  func testRecordingModeStillRespectsRecognitionEnabledPolicy() throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let disabledContext = try XCTUnwrap(GestureRecognitionContext(identifier: "disabled-context"))

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        recognitionContext: { _ in disabledContext },
        isRecognitionEnabled: { context in
          context != disabledContext
        },
        areModifiersSatisfied: { _, _ in false }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )
    recognizer.isRecordingModeEnabled = true

    recognizer.start()

    let result = eventSource.send(
      makeGestureInputEvent(kind: .buttonDown(.secondary), location: .init(x: 10, y: 10))
    )

    assertDisposition(result, .passThrough)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .recognitionDisabled)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
  }

  func testStrayDragAndUpEventsDoNotEvaluateRecognitionPolicy() {
    let eventSource = GestureEventSourceDouble(startResult: true)
    var recognitionPolicyCallCount = 0

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        isRecognitionEnabled: { _ in
          recognitionPolicyCallCount += 1
          return false
        }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonMoved(.secondary), location: .init(x: 20, y: 20))
      ),
      .passThrough
    )
    assertDisposition(
      eventSource.send(
        makeGestureInputEvent(kind: .buttonUp(.secondary), location: .init(x: 20, y: 20))
      ),
      .passThrough
    )

    XCTAssertEqual(recognitionPolicyCallCount, 0)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
  }

  func testRecognitionDisabledFailureClearsWhenRecognitionBecomesEnabledAgain() throws {
    let eventSource = GestureEventSourceDouble(startResult: true)
    let disabledContext = try XCTUnwrap(GestureRecognitionContext(identifier: "disabled-context"))
    let enabledContext = try XCTUnwrap(GestureRecognitionContext(identifier: "enabled-context"))
    let currentContext = MutableRecognitionContext(disabledContext)
    var clickRequestPoints: [GesturePoint] = []

    let configuration: GestureRecognizerConfiguration<UUID> =
      makeGestureRecognizerTestConfiguration(
        onReplayRequested: { request in
          if case let .click(_, point) = request {
            clickRequestPoints.append(point)
          }
        },
        recognitionContext: { _ in currentContext.value },
        isRecognitionEnabled: { context in
          context != disabledContext
        },
        areModifiersSatisfied: { _, _ in true }
      )

    let recognizer = GestureRecognizer<UUID>(
      eventSource: eventSource,
      configuration: configuration
    )

    recognizer.start()

    let disabledResult = eventSource.send(
      makeGestureInputEvent(
        kind: .buttonDown(.secondary),
        location: .init(x: 10, y: 10)
      ))
    assertDisposition(disabledResult, .passThrough)
    XCTAssertEqual(recognizer.snapshot.status.lastFailure, .recognitionDisabled)

    currentContext.value = enabledContext
    let enabledResult = eventSource.send(
      makeGestureInputEvent(
        kind: .buttonDown(.secondary),
        location: .init(x: 20, y: 20)
      ))
    assertDisposition(enabledResult, .consume)
    XCTAssertNil(recognizer.snapshot.status.lastFailure)
    XCTAssertFalse(recognizer.snapshot.status.isCapturingGesture)
    XCTAssertTrue(clickRequestPoints.isEmpty)
  }
}

@MainActor
private final class MutableRecognitionContext {
  var value: GestureRecognitionContext?

  init(_ value: GestureRecognitionContext? = nil) {
    self.value = value
  }
}
