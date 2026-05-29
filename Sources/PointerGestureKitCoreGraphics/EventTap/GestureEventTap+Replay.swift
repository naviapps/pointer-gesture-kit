import class CoreGraphics.CGEvent
import class CoreGraphics.CGEventSource
import enum CoreGraphics.CGEventField
import enum CoreGraphics.CGEventSourceStateID
import enum CoreGraphics.CGEventTapLocation
import enum CoreGraphics.CGEventType
import PointerGestureKit

extension GestureEventTap {
  /// Replays the concrete Core Graphics events for a recognizer replay request.
  public func replay(_ request: GestureReplayRequest) {
    switch request {
    case let .click(button, location):
      replayClick(button: button, at: location)
    case let .drag(button, points):
      replayDrag(button: button, points: points)
    case let .release(button, location):
      replayRelease(button: button, at: location)
    }
  }

  /// Replays a full pointer-button click at the provided gesture location.
  ///
  /// This posts both button-down and button-up events before returning.
  private func replayClick(button: PointerButton, at location: GesturePoint) {
    let source = replayEventSource()
    let eventTypes = button.cgEventTypes
    guard
      let down = replayedButtonEvent(
        type: eventTypes.down,
        button: button,
        at: location,
        source: source
      )
    else { return }
    guard
      let up = replayedButtonEvent(
        type: eventTypes.up,
        button: button,
        at: location,
        source: source
      )
    else { return }

    markAsSingleClick(down.event)
    markAsSingleClick(up.event)

    postReplayedButtonEvents([down, up])
  }

  /// Replays only a pointer-button release at the provided gesture location.
  ///
  /// Use this after a match consumes the original button release.
  private func replayRelease(button: PointerButton, at location: GesturePoint) {
    let source = replayEventSource()
    let eventTypes = button.cgEventTypes
    guard
      let up = replayedButtonEvent(
        type: eventTypes.up,
        button: button,
        at: location,
        source: source
      )
    else { return }

    postReplayedButtonEvents([up])
  }

  /// Replays a consumed pointer-button down, drag, and release sequence.
  private func replayDrag(button: PointerButton, points: [GesturePoint]) {
    guard let firstPoint = points.first else { return }
    guard points.count > 1 else {
      replayClick(button: button, at: firstPoint)
      return
    }

    let source = replayEventSource()
    let eventTypes = button.cgEventTypes
    guard
      let down = replayedButtonEvent(
        type: eventTypes.down,
        button: button,
        at: firstPoint,
        source: source
      )
    else { return }
    guard
      let up = replayedButtonEvent(
        type: eventTypes.up, button: button, at: points[points.count - 1], source: source)
    else { return }

    guard
      let dragEvents = replayedButtonEvents(
        type: eventTypes.dragged, button: button, at: points.dropFirst(), source: source)
    else { return }

    postReplayedButtonEvents([down] + dragEvents + [up])
  }

  private func postReplayedButtonEvents(_ events: [ReplayedButtonEvent]) {
    suppressNextSyntheticEventSignatures(events.map(\.signature))
    for event in events {
      event.event.post(tap: .cghidEventTap)
    }
  }

}

private let singleClickState: Int64 = 1

private struct ReplayedButtonEvent {
  let event: CGEvent
  let signature: SyntheticEventSignature
}

private func replayEventSource() -> CGEventSource? {
  let source = CGEventSource(stateID: .hidSystemState)
  source?.localEventsSuppressionInterval = 0
  return source
}

private func replayedButtonEvent(
  type: CGEventType,
  button: PointerButton,
  at location: GesturePoint,
  source: CGEventSource?
) -> ReplayedButtonEvent? {
  guard let cgMouseButton = button.cgMouseButton else { return nil }
  guard
    let event = CGEvent(
      mouseEventSource: source,
      mouseType: type,
      mouseCursorPosition: location.cgPoint,
      mouseButton: cgMouseButton
    )
  else {
    return nil
  }
  SyntheticEventSignature.markReplayed(event)
  return ReplayedButtonEvent(
    event: event,
    signature: SyntheticEventSignature.replayed(type: type, button: button)
  )
}

private func replayedButtonEvents(
  type: CGEventType,
  button: PointerButton,
  at locations: ArraySlice<GesturePoint>,
  source: CGEventSource?
) -> [ReplayedButtonEvent]? {
  var events: [ReplayedButtonEvent] = []
  events.reserveCapacity(locations.count)
  for location in locations {
    guard let event = replayedButtonEvent(type: type, button: button, at: location, source: source)
    else {
      return nil
    }
    events.append(event)
  }
  return events
}

private func markAsSingleClick(_ event: CGEvent) {
  event.setIntegerValueField(.mouseEventClickState, value: singleClickState)
}
