import Foundation
import PointerGestureKit

@MainActor
final class GestureEventSourceDouble: GestureEventSource {
  private var startResults: [Bool]
  private let repeatedStartResult: Bool?

  private(set) var startCount = 0
  private(set) var stopCount = 0
  private var handler: (@MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition)?

  init(startResult: Bool) {
    startResults = [startResult]
    repeatedStartResult = startResult
  }

  init(startResults: [Bool]) {
    self.startResults = startResults
    repeatedStartResult = nil
  }

  func start(
    handler: @escaping @MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition
  ) -> Bool {
    startCount += 1
    let didStart: Bool
    if startResults.isEmpty {
      didStart = repeatedStartResult ?? false
    } else {
      didStart = startResults.removeFirst()
    }
    self.handler = didStart ? handler : nil
    return didStart
  }

  func stop() {
    stopCount += 1
    handler = nil
  }

  func send(_ event: GestureInputEvent) -> GestureEventDisposition {
    handler?(event) ?? .passThrough
  }
}

func makeGestureInputEvent(
  kind: GestureInputEvent.Kind,
  location: GesturePoint,
  modifiers: GestureModifierFlags = []
) -> GestureInputEvent {
  GestureInputEvent(kind: kind, location: location, modifiers: modifiers)
}

func makeCancelGestureInputEvent(
  location: GesturePoint = .zero,
  modifiers: GestureModifierFlags = []
) -> GestureInputEvent {
  GestureInputEvent(kind: .cancel, location: location, modifiers: modifiers)
}
