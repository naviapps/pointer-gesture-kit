# AGENTS.md

## Scope and sources of truth

- This repository owns PointerGestureKit, PointerGestureKitCoreGraphics. Keep reusable mechanism here and product policy in the host app.
- Read [README.md](README.md) for integration contracts and the repository map.
- `Package.swift` defines products, targets, platform requirements, and dependency resolution. `Makefile` and `.github/workflows` define the checks.
- Read the relevant local API catalog before changing a public contract:
  - [PointerGestureKit](Sources/PointerGestureKit/PointerGestureKit.docc/PointerGestureKit.md)
  - [PointerGestureKitCoreGraphics](Sources/PointerGestureKitCoreGraphics/PointerGestureKitCoreGraphics.docc/PointerGestureKitCoreGraphics.md)
- Read [SECURITY.md](SECURITY.md) before changing sensitive-data or live-system boundaries.

## Contracts to preserve

- Keep CoreGraphics event capture out of the recognizer core; the host owns command execution, UI and permission onboarding.
- Preserve exact matches, duplicate-pattern replacement, context/session snapshots, and consumed-input replay.
- Gesture coordinates increase downward. Platform/view coordinate transforms belong at the adapter or host boundary.
- GestureModifierFlags preserves raw package bits, including unknown bits; platform masks are mapped by the adapter.
- Keep observation tokens, start-retry tasks and event-tap teardown lifetimes explicit.

## Change and validation

- Keep README examples and DocC symbols aligned with the implementation. Historical CHANGELOG entries describe released behavior; do not rewrite them to match a newer API.
- Use `make check` before a PR; it covers formatting, Debug/Release builds and strict-concurrency tests.
- Use injected providers and fixtures for effects. Report live OS/provider checks separately from deterministic tests.
- Do not hand-edit `.build`, generated projects/DocC output, dependency caches, or local secret files.
