# Changelog

All notable user-facing changes to PointerGestureKit will be documented in this file.

Released versions follow semantic versioning.

## [Unreleased]

No changes yet.

## [0.2.0] - 2026-07-12

### Changed

- Raised the package requirement to Swift 6.2 for actor-isolated resource cleanup.
- Moved recognizer deinitialization cleanup into a non-generic lifetime owner so optimized Release
  builds preserve replay and event-source shutdown behavior without triggering a compiler crash.
- Updated installation guidance to use the 0.2.0 release line.
- Removed the redundant `GesturePatternCatalog` and `GesturePatternValidator` wrappers. Pattern
  registration reports an empty pattern directly; duplicate registration intentionally replaces
  the previous match, while settings-level conflict policy remains with the host.
- Recording mode now records directions without requesting a matcher, while
  still respecting `isRecognitionEnabled` for the active context.
- `GestureObservationToken` is main-actor isolated and exposes one synchronous, idempotent
  `cancel()` operation.
- `GestureRecognizerTuning.standard` provides production defaults, while
  `validated(...)` rejects invalid custom values instead of silently changing behavior.
- `GestureRecognizerState.Trace` now exposes `tailPoint` for low-latency live
  rendering without publishing the full raw-point history on every pointer move.
- `GestureRecognizerConfiguration` now accepts `passesThroughEmptyMatcher` so hosts can leave
  pointer input untouched when the active matcher contains no patterns.
- `PointerButton.additionalButtonNumber` and its initializer are now named `auxiliaryButtonID`
  to match the package's primary, secondary, middle, and auxiliary button terminology.
- `GestureEventSource` is main-actor isolated instead of requiring `Sendable`, matching its UI
  event-loop lifecycle and delivery contract.
- Replay requests now include `dragStart(button:points:)` for replaying a consumed button-down and
  drag prefix when recognition stops before the physical button is released.
- Core Graphics replay docs now describe empty and single-point drag replay
  behavior and replayed-event suppression.
- `GesturePatternMatcher.register(pattern:match:)` returns whether the non-empty pattern was
  registered.
- `GesturePatternMatcher.match(pattern:)` is available for exact-pattern lookup
  in host-app tests.
- `GestureEventDisposition` now exposes whether the original platform event
  should be consumed through `consumesOriginalEvent`.
- `GestureInputEvent.Kind.buttonDragged(_:)` is now
  `GestureInputEvent.Kind.buttonMoved(_:)` so the platform-neutral input model
  describes pointer movement instead of Core Graphics dragged-event naming.
- Recognizer lifecycle, failure, and event-disposition values are finite enums
  while observable state, input, replay, context, and geometry remain comparable
  value models.
- Added README links to release notes.
- Clarified that security updates target the latest released version.

### Removed

- Removed `GestureEventDisposition` `CaseIterable`/`allCases` conformance so
  event-disposition policy exposes only the returned action and
  `consumesOriginalEvent` decision instead of a redundant enumeration helper.
- Removed the `GestureInputEvent.Kind.buttonDragged(_:)` spelling; no alias is
  kept because platform-specific dragged terminology belongs in adapters.
- Removed `GestureDirection` `CaseIterable`/`allCases` conformance so the
  public geometry contract is the four direction cases themselves rather than
  an ordered collection helper.
- Removed `GesturePatternValidator`; settings-level duplicate policy is outside matching.
- Removed public replay-request convenience properties that duplicated enum
  payload pattern matching.
- Removed `Hashable` from observable input, replay, context, geometry, tuning, and recognizer-state
  values whose public contract only requires equality and concurrency safety.

## [0.1.0] - 2026-05-29

### Added

- Initial public release.
- Added the `PointerGestureKit` core product for platform-neutral pointer-button gesture
  recognition, matching, replay requests, recognition policy, tuning, and observation.
- Added the `PointerGestureKitCoreGraphics` product for live macOS Core Graphics event-tap capture,
  pointer-button mapping, point conversion, and replay handling.
