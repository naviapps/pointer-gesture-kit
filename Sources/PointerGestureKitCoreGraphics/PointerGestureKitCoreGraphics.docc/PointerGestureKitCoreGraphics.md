# ``PointerGestureKitCoreGraphics``

Capture macOS pointer-button drag input with a Core Graphics event tap.

## Overview

PointerGestureKitCoreGraphics provides the live macOS adapter for `PointerGestureKit`. Use
``GestureEventTap`` when a macOS app needs to capture pointer-button drag gestures with a Core
Graphics session event tap. It defaults to the secondary button and can be configured for primary,
middle, or additional pointer buttons. Passing an empty captured-button set captures no input and
``GestureEventTap/start(handler:)`` returns `false`.

When a recognizer uses a non-default recognition button, create ``GestureEventTap`` with a
`capturedButtons` set that includes that same button.

The adapter maps configured mouse-button down, dragged, up, and Escape key-down events to
platform-neutral `PointerGestureKit.GestureInputEvent` values. Primary buttons use left-mouse
events, secondary buttons use right-mouse events, and middle or additional buttons use other-mouse
events with the Core Graphics button number.

## Usage

Create one event tap and pass it both as the recognizer event source and as the replay handler:

```swift
import PointerGestureKit
import PointerGestureKitCoreGraphics

enum AppCommand: Sendable {
  case showInspector
}

@MainActor
func makeMatcher() -> GesturePatternMatcher<AppCommand> {
  var matcher = GesturePatternMatcher<AppCommand>()
  matcher.register(pattern: [.down, .right], match: .showInspector)
  return matcher
}

@MainActor
func run(_: AppCommand) {
}

@MainActor
let eventTap = GestureEventTap()

@MainActor
let configuration = GestureRecognizerConfiguration<AppCommand>(
  makeMatcher: { _ in makeMatcher() },
  onReplayRequested: eventTap.replay,
  onMatch: { command in
    run(command)
  }
)

@MainActor
let recognizer = GestureRecognizer(
  eventSource: eventTap,
  configuration: configuration
)

recognizer.start()
```

For a non-default recognition button, configure the adapter and recognizer with the same button:

```swift
let eventTap = GestureEventTap(capturedButtons: [.primary])

let configuration = GestureRecognizerConfiguration<AppCommand>(
  makeMatcher: { _ in makeMatcher() },
  onReplayRequested: eventTap.replay,
  onMatch: { command in
    run(command)
  },
  recognitionButton: .primary
)
```

## Responsibility Boundary

PointerGestureKitCoreGraphics owns the live Core Graphics event-tap adapter for pointer-button
drag input, Escape-key cancellation, modifier mapping, and pointer-button replay adaptation. Use
``GestureEventTap/replay(_:)`` to handle click, drag, and release replay
requests emitted by the recognizer. A click replay posts button-down and button-up events before
returning. A drag replay posts down, dragged points, and up; empty drag requests are ignored.

Keep command execution, trace UI, Accessibility permission presentation, privacy policy,
persistence, telemetry, analytics, and product behavior in the host app. This target translates
supported `CGEvent` values into `PointerGestureKit.GestureInputEvent` values, applies the
recognizer's event-disposition decision, and replays concrete Core Graphics events requested by
`GestureReplayRequest` values. It reports event-tap creation failure through
``GestureEventTap/start(handler:)``; host apps remain responsible for Accessibility permission
onboarding and recovery UI.

## Topics

### Event Tap

- ``GestureEventTap``

### Replay

- ``GestureEventTap/replay(_:)``

### Core Graphics Conversion

- ``PointerGestureKit/GesturePoint/init(_:)``
- ``PointerGestureKit/GesturePoint/cgPoint``
