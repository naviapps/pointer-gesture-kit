# ``PointerGestureKit``

Recognize pointer gestures from platform-neutral input events.

## Overview

PointerGestureKit contains the recognizer core, direction model, matcher,
recognition policy inputs, observable state, and event-source protocol used to
turn pointer-button drag paths into app-owned matches. Recognition defaults to
the secondary button and can be configured for primary, middle, or auxiliary
pointer buttons.
Gesture movement is recorded as one of four cardinal directions: up, down, left,
and right. Movement without a dominant axis does not add a direction.
`GesturePoint` values use gesture coordinates where positive vertical movement resolves as down.
The recognizer passes through input with non-finite coordinates.

The core target does not depend on AppKit, Core Graphics, or live input capture. Host apps provide
event sources to ``GestureRecognizer`` and provide recognition-context policy plus callbacks through
``GestureRecognizerConfiguration``. Trace rendering, Accessibility permission presentation,
persistence, telemetry, and command execution stay outside this target.
Use ``GestureInputEvent/Kind`` to distinguish pointer-button down, move, and up input events.

Use ``GesturePatternMatcher`` to map direction patterns to app-owned match values, then create a
``GestureRecognizer`` with an event source and configuration.

## Usage

Register app-owned matches with ``GesturePatternMatcher`` and pass the matcher to a
``GestureRecognizer`` configuration:

```swift
import PointerGestureKit

enum AppCommand: Sendable {
  case showInspector
  case focusSearch
}

@MainActor
func makeGestureMatcher() -> GesturePatternMatcher<AppCommand> {
  var matcher = GesturePatternMatcher<AppCommand>()
  matcher.register(pattern: [.down, .right], match: .showInspector)
  matcher.register(pattern: [.up, .left], match: .focusSearch)
  return matcher
}
```

Pattern matching is exact. During normal recognition, trace visibility begins when the current
direction sequence is a valid matcher prefix; completed matches still require an exact registered
pattern. Host apps validate settings-level conflicts before building a matcher.
Use ``GestureRecognizerConfiguration`` to provide policy callbacks, replay handling, match handling,
and tuning. Keep the returned ``GestureObservationToken`` while status or trace observation should
remain active.
Use ``GestureRecognizer/observeTrace(_:)`` for live overlay feedback; after a trace becomes visible,
tail-point and hidden-state updates are delivered during input handling so hosts can render fast
gestures without an extra main-actor turn.

## Recognition Pipeline

The recognizer turns platform-neutral input into a match through a small fixed pipeline:

1. Capture raw gesture points from the configured pointer-button input.
2. Resolve dominant-axis movement into cardinal directions.
3. Build a completed direction sequence for the gesture session.
4. Match the completed sequence exactly against registered patterns.
5. Emit either an app-owned match or a pointer-button replay request.

## Responsibility Boundary

PointerGestureKit owns direction recognition, matching, recognizer state, trace observation,
event-disposition modeling, event-source start retry behavior, and platform-neutral event-source
contracts. Event-source implementations expose ``GestureEventSource/start(handler:)`` and
``GestureEventSource/stop()`` as the only live-input lifecycle hooks consumed by the recognizer.
They apply the returned ``GestureEventDisposition`` to the original platform event:
``GestureEventDisposition/consume`` suppresses it, while
``GestureEventDisposition/passThrough`` leaves it in the platform event stream.

PointerGestureKit does not own command catalogs, command execution, overlay UI, Accessibility
permission presentation, privacy disclosures, persistence, telemetry, analytics, non-macOS
event-source adapters, or diagonal gesture directions.

## Topics

### Recognizer

- ``GestureRecognizer``
- ``GestureRecognizer/init(eventSource:configuration:)``
- ``GestureRecognizer/isRecordingModeEnabled``
- ``GestureRecognizer/start()``
- ``GestureRecognizer/stop()``
- ``GestureRecognizer/retryStartNow()``
- ``GestureRecognizer/cancelActiveGesture()``
- ``GestureRecognizer/snapshot``
- ``GestureRecognizer/observe(_:)``
- ``GestureRecognizer/observeStatus(_:)``
- ``GestureRecognizer/observeTrace(_:)``
- ``GestureRecognizerConfiguration``
- ``GestureRecognizerConfiguration/init(makeMatcher:onReplayRequested:onMatch:recognitionButton:recognitionContext:isRecognitionEnabled:passesThroughEmptyMatcher:areModifiersSatisfied:tuning:)``
- ``GestureRecognitionContext``
- ``GestureRecognitionContext/init(identifier:)``
- ``GestureRecognitionContext/identifier``
- ``GestureRecognizerFailure``
- ``GestureRecognizerFailure/eventSourceStartFailed``
- ``GestureRecognizerFailure/recognitionDisabled``
- ``GestureRecognizerFailure/modifiersNotSatisfied``
- ``GestureRecognizerFailure/gestureSessionExpired``

### Matching

- ``GesturePatternMatcher``
- ``GesturePatternMatcher/init()``
- ``GesturePatternMatcher/register(pattern:match:)``
- ``GesturePatternMatcher/match(pattern:)``
- ``GestureDirection``
- ``GestureDirection/up``
- ``GestureDirection/down``
- ``GestureDirection/left``
- ``GestureDirection/right``

### Input and Geometry

- ``GestureInputEvent``
- ``GestureInputEvent/init(kind:location:modifiers:)``
- ``GestureInputEvent/Kind``
- ``GestureInputEvent/Kind/buttonDown(_:)``
- ``GestureInputEvent/Kind/buttonMoved(_:)``
- ``GestureInputEvent/Kind/buttonUp(_:)``
- ``GestureInputEvent/Kind/cancel``
- ``GestureInputEvent/kind``
- ``GestureInputEvent/location``
- ``GestureInputEvent/modifiers``
- ``GestureEventDisposition``
- ``GestureEventDisposition/consume``
- ``GestureEventDisposition/passThrough``
- ``GestureEventDisposition/consumesOriginalEvent``
- ``GestureReplayRequest``
- ``GestureReplayRequest/click(button:at:)``
- ``GestureReplayRequest/drag(button:points:)``
- ``GestureReplayRequest/dragStart(button:points:)``
- ``GestureReplayRequest/release(button:at:)``
- ``PointerButton``
- ``PointerButton/primary``
- ``PointerButton/secondary``
- ``PointerButton/middle``
- ``PointerButton/init(auxiliaryButtonID:)``
- ``PointerButton/auxiliaryButtonID``
- ``GesturePoint``
- ``GesturePoint/init(x:y:)``
- ``GesturePoint/x``
- ``GesturePoint/y``
- ``GesturePoint/zero``
- ``GestureModifierFlags``
- ``GestureModifierFlags/init(rawValue:)``
- ``GestureModifierFlags/rawValue``
- ``GestureModifierFlags/command``
- ``GestureModifierFlags/option``
- ``GestureModifierFlags/control``
- ``GestureModifierFlags/shift``

### Policy and Tuning

- ``GestureRecognizerTuning``
- ``GestureRecognizerTuning/standard``
- ``GestureRecognizerTuning/validated(minimumGestureStartAxisDistance:minimumDirectionChangeAxisDistance:maximumGestureSessionDuration:maximumRawPointCount:eventSourceStartRetryDelays:)``
- ``GestureRecognizerTuning/ValidationError``
- ``GestureRecognizerTuning/minimumGestureStartAxisDistance``
- ``GestureRecognizerTuning/minimumDirectionChangeAxisDistance``
- ``GestureRecognizerTuning/maximumGestureSessionDuration``
- ``GestureRecognizerTuning/maximumRawPointCount``
- ``GestureRecognizerTuning/eventSourceStartRetryDelays``
- ``GestureRecognizer/updateTuning(_:)``

### Observation

- ``GestureRecognizerState``
- ``GestureRecognizerState/init(status:trace:)``
- ``GestureRecognizerState/status``
- ``GestureRecognizerState/trace``
- ``GestureRecognizerState/Status``
- ``GestureRecognizerState/Status/init(lifecycle:isCapturingGesture:isRecordingModeEnabled:lastRecordedDirections:lastFailure:)``
- ``GestureRecognizerState/Status/lifecycle``
- ``GestureRecognizerState/Status/isCapturingGesture``
- ``GestureRecognizerState/Status/isRecordingModeEnabled``
- ``GestureRecognizerState/Status/lastRecordedDirections``
- ``GestureRecognizerState/Status/lastFailure``
- ``GestureRecognizerState/Status/Lifecycle``
- ``GestureRecognizerState/Status/Lifecycle/idle``
- ``GestureRecognizerState/Status/Lifecycle/starting``
- ``GestureRecognizerState/Status/Lifecycle/ready``
- ``GestureRecognizerState/Status/Lifecycle/retrying``
- ``GestureRecognizerState/Status/Lifecycle/failed``
- ``GestureRecognizerState/Trace``
- ``GestureRecognizerState/Trace/init(isVisible:rawPoints:directions:directionEndpoints:tailPoint:)``
- ``GestureRecognizerState/Trace/isVisible``
- ``GestureRecognizerState/Trace/rawPoints``
- ``GestureRecognizerState/Trace/directions``
- ``GestureRecognizerState/Trace/directionEndpoints``
- ``GestureRecognizerState/Trace/tailPoint``
- ``GestureObservationToken``
- ``GestureObservationToken/cancel()``

### Event Source

- ``GestureEventSource``
- ``GestureEventSource/start(handler:)``
- ``GestureEventSource/stop()``
