# ``PointerGestureKitCoreGraphics``

Capture macOS pointer-button drag input with a Core Graphics event tap.

## Overview

PointerGestureKitCoreGraphics provides the live macOS adapter for `PointerGestureKit`. Use
``GestureEventTap`` when a macOS app needs to capture pointer-button drag gestures with a Core
Graphics session event tap. It defaults to the secondary button and can be configured for primary,
middle, or auxiliary pointer buttons. Passing an empty captured-button set captures no input and
``GestureEventTap/start(handler:)`` returns `false`.

When a recognizer uses a non-default recognition button, create ``GestureEventTap`` with a
`capturedButtons` set that includes that same button.

The adapter maps configured mouse-button down, drag-move, up, and Escape key-down events to
platform-neutral `PointerGestureKit.GestureInputEvent` values. Primary buttons use left-mouse
events, secondary buttons use right-mouse events, and middle or auxiliary buttons use other-mouse
events with the Core Graphics button number.

## Usage

Create one event tap at the live system boundary, then bridge Core Graphics points into
`GesturePoint` values when replaying concrete pointer events:

```swift
import CoreGraphics
import PointerGestureKit
import PointerGestureKitCoreGraphics

@MainActor
func makeEventTap() -> GestureEventTap {
  let eventTap = GestureEventTap(capturedButtons: [.secondary])
  let replayPoint = GesturePoint(CGPoint(x: 120, y: 80))
  let originalPoint = replayPoint.cgPoint

  eventTap.replay(.click(button: .secondary, at: replayPoint))
  _ = originalPoint
  return eventTap
}
```

For recognizer wiring, pass the same event tap as the recognizer event source and replay handler.
For a non-default recognition button, configure the adapter and recognizer with the same button,
such as `.primary`.

Convert Core Graphics points at the adapter boundary when a host app needs to
move between live `CGPoint` values and neutral gesture coordinates:

```swift
import CoreGraphics
import PointerGestureKit
import PointerGestureKitCoreGraphics

let point = GesturePoint(CGPoint(x: 10, y: 20))
```

## Responsibility Boundary

PointerGestureKitCoreGraphics owns the live Core Graphics event-tap adapter for pointer-button
drag input, Escape-key cancellation, modifier mapping, and pointer-button replay adaptation. Use
``GestureEventTap/replay(_:)`` to handle click, drag, and release replay
requests emitted by the recognizer. A click replay posts button-down and button-up events before
returning. A drag replay posts down, move, and up events; empty drag requests are ignored and
single-point drag requests replay as a click at that point. Replayed events are marked so the tap can
ignore them if Core Graphics reports them back through the event stream.

Keep command execution, trace UI, Accessibility permission presentation, privacy policy,
persistence, telemetry, analytics, and product behavior in the host app. This target translates
supported `CGEvent` values into `PointerGestureKit.GestureInputEvent` values, applies the
recognizer's event-disposition decision, and replays concrete Core Graphics events requested by
`GestureReplayRequest` values. It reports event-tap creation failure through
``GestureEventTap/start(handler:)``. Host applications are responsible for Accessibility
permission onboarding and recovery UI.
The ``PointerGestureKit/GesturePoint/init(_:)`` and ``PointerGestureKit/GesturePoint/cgPoint``
bridges preserve coordinates and expose the core ``PointerGestureKit/GesturePoint/isFinite`` check
for non-finite input. They do not flip coordinate axes; platform-specific
screen or view coordinate transforms belong in the host app.

## Topics

### Event Tap

- ``GestureEventTap``
- ``GestureEventTap/init(capturedButtons:)``
- ``GestureEventTap/start(handler:)``
- ``GestureEventTap/stop()``
- ``GestureEventTap/replay(_:)``

### Core Graphics Bridges

- ``PointerGestureKit/GesturePoint/init(_:)``
- ``PointerGestureKit/GesturePoint/cgPoint``
