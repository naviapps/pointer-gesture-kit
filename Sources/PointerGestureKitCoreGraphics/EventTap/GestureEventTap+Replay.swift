import class CoreGraphics.CGEvent
import class CoreGraphics.CGEventSource
import enum CoreGraphics.CGEventField
import enum CoreGraphics.CGEventSourceStateID
import enum CoreGraphics.CGEventTapLocation
import enum CoreGraphics.CGEventType
import PointerGestureKit

private let maximumReplayDragPointCount = 64

extension GestureEventTap {
  /// Replays the concrete Core Graphics events for a recognizer replay request.
  ///
  /// Click requests post button-down and button-up events. Drag requests post down, move, and up
  /// events; empty drag requests are ignored and single-point drag requests replay as a click.
  /// Drag-start requests post down and move events without a release. Release requests post only a
  /// button-up event.
  ///
  /// Replayed events are marked so this tap can ignore them if Core Graphics reports them back
  /// through the event stream.
  public func replay(_ request: GestureReplayRequest) {
    switch request {
    case let .click(button, location):
      replayClick(button: button, at: location)
    case let .drag(button, points):
      replayDrag(button: button, points: points)
    case let .dragStart(button, points):
      replayDragStart(button: button, points: points)
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
  ///
  /// Empty drag requests do nothing. A single-point drag request is replayed as a click at that
  /// point.
  private func replayDrag(button: PointerButton, points: [GesturePoint]) {
    let replayPoints = coalescedReplayDragPoints(
      points,
      maximumPointCount: maximumReplayDragPointCount
    )
    guard let firstPoint = replayPoints.first else { return }
    guard replayPoints.count > 1 else {
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
        type: eventTypes.up,
        button: button,
        at: replayPoints[replayPoints.count - 1],
        source: source
      )
    else { return }

    guard
      let dragEvents = replayedButtonEvents(
        type: eventTypes.moved,
        button: button,
        at: replayPoints.dropFirst(),
        source: source
      )
    else { return }

    postReplayedButtonEvents([down] + dragEvents + [up])
  }

  /// Replays the consumed start of a pointer-button drag and leaves release to the real event stream.
  ///
  /// Empty drag-start requests do nothing. A single-point drag-start request posts only a
  /// button-down event at that point.
  private func replayDragStart(button: PointerButton, points: [GesturePoint]) {
    let replayPoints = coalescedReplayDragPoints(
      points,
      maximumPointCount: maximumReplayDragPointCount
    )
    guard let firstPoint = replayPoints.first else { return }

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

    guard replayPoints.count > 1 else {
      postReplayedButtonEvents([down])
      return
    }

    guard
      let dragEvents = replayedButtonEvents(
        type: eventTypes.moved,
        button: button,
        at: replayPoints.dropFirst(),
        source: source
      )
    else { return }

    postReplayedButtonEvents([down] + dragEvents)
  }

  private func postReplayedButtonEvents(_ events: [ReplayedButtonEvent]) {
    suppressNextSyntheticEventSignatures(events.map(\.signature))
    for event in events {
      event.event.post(tap: .cghidEventTap)
    }
  }
}

func coalescedReplayDragPoints(
  _ points: [GesturePoint],
  maximumPointCount: Int
) -> [GesturePoint] {
  let maximumPointCount = max(2, maximumPointCount)
  guard points.count > maximumPointCount else { return points }

  let lastIndex = points.count - 1
  let step = Double(lastIndex) / Double(maximumPointCount - 1)
  var coalesced: [GesturePoint] = []
  coalesced.reserveCapacity(maximumPointCount)

  for outputIndex in 0..<maximumPointCount {
    let sourceIndex =
      outputIndex == maximumPointCount - 1
      ? lastIndex
      : Int((Double(outputIndex) * step).rounded(.down))
    coalesced.append(points[sourceIndex])
  }

  return coalesced
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
  guard location.isFinite else { return nil }
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
