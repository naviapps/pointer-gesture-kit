# ``PointerGestureKit``

Recognize pointer gestures from platform-neutral input events.

## Overview

PointerGestureKit contains the recognizer core, direction model, matcher,
recognition policy inputs, observable state, and event-source protocol used to
turn pointer-button drag paths into app-owned matches. Recognition defaults to
the secondary button and can be configured for primary, middle, or additional
pointer buttons.
Gesture movement is recorded as one of four cardinal directions: up, down, left,
and right. Movement without a dominant axis does not add a direction.
`GesturePoint` values use gesture coordinates where positive vertical movement
resolves as down.

The core target does not depend on AppKit, Core Graphics, or live input capture. Host apps provide
event sources to ``GestureRecognizer`` and provide recognition-context policy plus callbacks through
``GestureRecognizerConfiguration``. Trace rendering, Accessibility permission presentation,
persistence, telemetry, and command execution stay outside this target.

Use ``GesturePatternMatcher`` to map direction patterns to app-owned match values, then create a
``GestureRecognizer`` with an event source and configuration.

## Usage

Register app-owned matches with ``GesturePatternMatcher``:

```swift
import PointerGestureKit

enum AppCommand: Sendable {
  case showInspector
  case focusSearch
}

var matcher = GesturePatternMatcher<AppCommand>()
matcher.register(pattern: [.down, .right], match: .showInspector)
matcher.register(pattern: [.up, .left], match: .focusSearch)
```

Pattern matching is exact: the completed gesture direction sequence must match a registered pattern.
Use ``GesturePatternCatalog`` when a host-owned settings UI needs to validate configured patterns
before building a matcher. It reports empty patterns and duplicate patterns, but shared prefixes are
valid because matching is exact. Use ``GesturePatternCatalog/ValidationIssue/patternIndex`` to
highlight the invalid host-defined pattern row and
``GesturePatternCatalog/ValidationIssue/relatedPatternIndex`` to reference the original row for
duplicates. The catalog validates only pattern shape; host apps still own command names, command
conflicts, persistence, and migration policy.
``GesturePatternMatcher/register(pattern:match:)`` returns `false` for empty patterns and otherwise
stores or replaces the exact pattern match.

Configure recognition callbacks, policy, and tuning through
``GestureRecognizerConfiguration``. The recognizer keeps gesture-session state
and emits app-owned matches; the host app decides how to execute commands.
Use the `onReplayRequested` initializer argument to handle ``GestureReplayRequest``
values after the recognizer consumes pointer-button input. Plain clicks request
a full click for the configured recognition button. Unmatched or recording-mode
drags request the consumed drag sequence so drag workflows can be restored;
a recognized match requests only the consumed button release. Replay requests expose their
configured ``GestureReplayRequest/button`` and final ``GestureReplayRequest/location`` for
host-side routing or diagnostics. Stopping or cancelling while consumed pointer-button input is
active also emits the replay needed to leave host input state consistent. Use the `onMatch`
initializer argument to receive the configured app-owned match value.

Recognition uses the secondary button by default. Set the `recognitionButton`
initializer argument when gestures should start from the primary, middle, or an
additional pointer button, and provide an event source that emits the same
button.

Use the `recognitionContext` initializer argument only when matching or policy
depends on the app, window, or surface under the gesture start point. Apps that
only need a current/frontmost context can ignore the point argument. Return
`nil` when no host context is active. Use `isRecognitionEnabled` to disable
recognition for a context without encoding that decision into the context
identifier. ``GestureRecognitionContext/init(identifier:)`` trims surrounding whitespace and
returns `nil` for blank identifiers, matching the no-context path.

Use ``GestureRecognizer/isRecordingModeEnabled`` only for teaching or recording
gesture patterns. Recording mode captures directions without requiring modifier
approval or a registered match, but it still respects the `isRecognitionEnabled`
initializer argument for the active context. Normal recognition mode also uses
the `areModifiersSatisfied` initializer argument plus the configured matcher.
A completed recording-mode drag still emits a consumed drag-sequence replay request
for the configured recognition button. Read
``GestureRecognizerState/Status/lastRecordedDirections`` from status observation when the host needs
the most recently completed sequence.

Use ``GestureRecognizer/start()`` to request event-source startup and
``GestureRecognizer/stop()`` to stop recognition, cancel pending startup retries,
clear active gesture state, and reset the last failure. Use
``GestureRecognizer/retryStartNow()`` only after a previous `start()` request
when the host wants to retry event-source startup immediately. Use
``GestureRecognizer/cancelActiveGesture()`` for user-driven cancellation of an
in-progress gesture; when no gesture session or pending button input exists, it
is a no-op and preserves the current failure state.

Use ``GestureRecognizer/observe(_:)`` for combined snapshots. Use
``GestureRecognizer/observeStatus(_:)`` or ``GestureRecognizer/observeTrace(_:)``
when a UI only needs one portion of the snapshot; those observers emit their
initial value immediately and then only emit when that portion changes. Use
``GestureRecognizerState/Status/lifecycle`` for event-source startup UI. A `.failed`
lifecycle means event-source startup failed with no scheduled retry; `.retrying`
means the configured retry schedule is active. Use
``GestureRecognizerState/Status/isCapturingGesture`` for active gesture capture state
and ``GestureRecognizerState/Status/isRecordingModeEnabled`` for the host-controlled
teaching/recording mode. Use ``GestureRecognizerState/Status/lastRecordedDirections`` for the most
recently completed sequence and ``GestureRecognizerState/Status/lastFailure`` for startup, policy,
modifier, and session-expiration failures. ``GestureRecognizerState/Trace/directionEndpoints``
contains the trace start point plus one normalized endpoint per direction for trace rendering.

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
contracts.

PointerGestureKit does not own command catalogs, command execution, overlay UI, Accessibility
permission presentation, privacy disclosures, persistence, telemetry, analytics, non-macOS
event-source adapters, or diagonal gesture directions.

## Topics

### Recognizer

- ``GestureRecognizer``
- ``GestureRecognizerConfiguration``
- ``GestureRecognitionContext``
- ``GestureRecognizerFailure``

### Matching

- ``GesturePatternCatalog``
- ``GesturePatternCatalog/ValidationIssue``
- ``GesturePatternMatcher``
- ``GestureDirection``

### Input and Geometry

- ``GestureInputEvent``
- ``GestureEventDisposition``
- ``GestureReplayRequest``
- ``PointerButton``
- ``GesturePoint``
- ``GestureModifierFlags``

### Policy and Tuning

- ``GestureRecognizerTuning``

### Observation

- ``GestureRecognizerState``
- ``GestureRecognizerState/Status``
- ``GestureRecognizerState/Status/Lifecycle``
- ``GestureRecognizerState/Trace``
- ``GestureObservationToken``

### Event Source

- ``GestureEventSource``
