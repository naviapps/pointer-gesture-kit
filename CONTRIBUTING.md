# Contributing

Thank you for your interest in improving PointerGestureKit.

## Scope

PointerGestureKit focuses on macOS pointer-gesture recognition, direction matching, recognizer
state observation, and the macOS Core Graphics event-tap adapter. Host-app concerns such as
command catalogs, overlay UI, Accessibility onboarding copy, persistence, syncing, telemetry, and
action execution should stay outside this package.

Keep changes focused. Avoid bundling unrelated refactors, formatting-only rewrites, and behavior
changes in the same pull request.

## Development

Local development commands use `make`.

Run the full local check before opening a pull request:

```sh
make check
```

For focused local work, run checks separately:

```sh
make format
make lint
make test
make build
make docc
```

## Pull Requests

Before submitting a pull request:

- Keep the public API surface minimal and documented.
- Add or update tests for behavior changes.
- Update README, DocC, or `CHANGELOG.md` when user-facing behavior changes.
- Do not commit generated build output, dependency caches, editor state, local tool state, secrets,
  tokens, private keys, personal data, local paths, private app metadata, or app-specific internal
  references.

## Security

Do not report vulnerabilities in public issues, pull requests, or discussions. Follow
[SECURITY.md](SECURITY.md) instead.
