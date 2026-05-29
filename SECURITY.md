# Security Policy

## Supported Versions

Before the first public release, security fixes target the default branch. After a public release,
security fixes target the latest released version.

## Reporting a Vulnerability

Report security issues through GitHub private vulnerability reporting for this repository.

Do not open a public issue, pull request, or discussion for vulnerabilities, suspected credential
exposure, privacy-sensitive behavior, or issues that could expose private user data.

If private vulnerability reporting is unavailable, open a public issue asking for a private
security contact channel. Do not include vulnerability details, exploit steps, logs, secrets,
tokens, private keys, personal data, local paths, private app metadata, or app-specific internal
references.

For private reports, include:

- Affected package version or commit
- Affected dependency versions if relevant
- A clear description of the behavior
- Reproduction steps or a minimal proof of concept
- Expected impact
- Affected public API, target, or subsystem

Use placeholders instead of secrets, tokens, private keys, personal data, local paths, private app
metadata, or app-specific internal references.

We will acknowledge valid reports as soon as practical and coordinate fixes before public
disclosure.

For non-security bugs, use the public bug report template.

## Scope

Security-sensitive areas include:

- macOS Accessibility-permission-dependent event tap startup delegated by host apps
- CGEvent tap creation, disabling, and re-enabling
- Pointer-button, drag, and key-event disposition
- Suppression of synthetic events when replaying host-app behavior
- Private user activity visible to host-app event handlers or overlays

PointerGestureKit does not collect, transmit, persist, or log pointer events by itself. Host
applications are responsible for Accessibility onboarding, storage, telemetry, logging, UI, and
privacy policies.
