---
name: andromeda-flutter-quality
description: Implement or review Andromeda Flutter code for Android and Web with robust state, responsive layout, accessibility, platform-safe storage, and focused tests. Use for Dart files, widgets, onboarding, navigation, themes, API integration, or Flutter dependency changes.
---

# Andromeda Flutter Quality

Follow the existing Material/Dart style and change the minimum surface needed for the requested behavior.

## Design before coding

- For visual direction, typography, spacing, color, component shape, responsive composition, or visual QA, apply `andromeda-mobile-visual-design`. Until the user approves a direction, the current screens and theme values are drafts rather than visual requirements.
- Inspect the surrounding widgets, theme tokens, navigation pattern, and existing tests.
- Keep presentation, user interaction, domain state, and transport concerns separable.
- Introduce state-management, routing, code-generation, or networking packages only when the current architecture cannot express the requirement cleanly.
- Prefer immutable data, explicit states, typed failures, small widget classes, const constructors, and narrow rebuild scopes.

## Model every visible state

Async UI must have intentional loading, success, empty, validation-error, transport-error, and retry behavior. A future or stream must not leave the user on an endless spinner after an exception or timeout.

After an await, verify the widget is still mounted before using its context or mutating state. Dispose controllers, focus nodes, subscriptions, and timers owned by a State object.

## Support Android and Web deliberately

- Avoid unconditional dart:io, Platform calls, filesystem assumptions, and mobile-only plugins in shared code.
- Treat localhost and LAN HTTP origins differently. WebCrypto-backed secure storage requires HTTPS or localhost; do not silently claim secure token persistence on an insecure LAN origin.
- Keep API base URLs configurable. A phone cannot reach a backend through the computer's 127.0.0.1.
- Handle browser refresh and direct navigation when navigation work introduces stable URLs.
- Verify release web behavior, not only Flutter's debug web server.

## Build resilient responsive UI

- Test narrow phones, wider browser viewports, text scaling, the software keyboard, and long localized text.
- Use SafeArea, scrollable content, LayoutBuilder or constraints where they solve an observed layout need.
- Avoid hard-coded dimensions that assume one screenshot size.
- Use the shared theme instead of duplicating colors, text styles, radii, or spacing.

## Accessibility

Give controls meaningful labels, semantics, focus order, sufficient contrast, and usable touch targets. Do not rely on color alone. Verify custom controls with keyboard and screen-reader semantics where applicable.

## Testing and verification

Add tests at the cheapest layer that proves behavior:

- unit tests for transformations and state transitions;
- widget tests for validation, navigation, loading/error/retry states, and accessibility-critical semantics;
- integration or manual device checks for platform plugins and cross-process API flows.

Before completion, run formatting, flutter analyze, flutter test, and flutter build web when Web is affected. Build Android when Android configuration or a platform plugin changes.
