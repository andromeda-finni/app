---
name: andromeda-mobile-visual-design
description: Design, implement, and audit Andromeda's Android-first Flutter visual system and screens using intentional typography, spacing, color, layout, components, accessibility, and visual QA. Use for UI direction, ThemeData or design tokens, screen composition, responsive behavior, and visual polish; do not use for backend-only or logic-only changes.
---

# Andromeda Mobile Visual Design

Build a coherent mobile product, not a collection of individually styled screens.

## Product context

- Andromeda is an Android-first Flutter application that teaches financial literacy through a pet, wallets, budgets, quests, goals, purchases, delayed rewards, and parent-assigned tasks.
- Child-facing and parent-facing flows share one product identity but may use different density, tone, and information hierarchy when their jobs differ.
- Existing screens, `lib/theme/app_theme.dart`, fonts, colors, spacing, illustrations, and component shapes are exploratory drafts. Treat them as implementation inventory, not approved design truth, unless the user explicitly approves them.
- Preserve functional flows, content meaning, authorization boundaries, and economy rules. A visual redesign does not authorize changing product behavior.
- Do not infer a child's age or introduce child PII. When age materially affects a design decision, keep the choice provisional or ask for direction.

This skill owns visual direction, design-system decisions, composition, and visual QA. Use `andromeda-flutter-quality` alongside it for general widget architecture, state, lifecycle, platform safety, and Flutter testing; do not expand this skill into a general Dart review.

## Choose the working mode

### Establish the visual foundation

Use when the product has no approved visual system or is undergoing a substantial redesign.

1. Inspect product flows, roles, content, assets, and technical constraints without inheriting draft styling by default.
2. Define the interface job, audience, desired emotional tone, information priority, and one memorable visual idea.
3. Propose a small set of materially different directions when the direction is genuinely undecided. Show typography, color roles, spacing rhythm, component shape, illustration treatment, and one representative screen or component state.
4. Label every decision as repository fact, user-approved direction, or provisional proposal.
5. Do not roll a provisional direction across many screens or freeze golden snapshots as the product baseline until it is approved.
6. Once approved, encode the system in Flutter theme and token primitives and document it in the existing design-system document or `docs/design-system.md` when the task includes establishing that artifact.

### Design or implement a screen

Use approved tokens and shared components when they exist. If they do not, make the smallest coherent provisional extension and disclose it; do not silently create a second visual language.

Before implementation, define:

- the user role and task;
- the primary action and reading order;
- required content and interaction states;
- content that must remain visible above the fold;
- expected small-screen, large-text, keyboard, and offline or error behavior.

Start with hierarchy and layout, then typography and color, then polish and motion. Decorative art must support the task rather than compete with controls, balances, warnings, or learning content.

### Audit an existing interface

When no visual direction is approved, audit universal quality only: hierarchy, readability, spacing rhythm, responsiveness, accessibility, state coverage, and interaction clarity. Do not score conformity to the current drafts.

When a system is approved, also identify token drift, duplicate component styling, raw values, and inconsistent states. Report exact files and the shared token or component that should replace each deviation.

## Design-system rules

- Centralize semantic color roles, `TextTheme`, spacing, radii, icon sizes, control sizes, elevation, and motion. Prefer `ThemeData`, `ColorScheme`, and focused `ThemeExtension`s over unrelated global constants.
- Name tokens by role or scale, not by a single screen. Components consume tokens; screens compose components.
- After a system is approved, avoid raw font sizes, colors, padding, radii, or animation durations in feature widgets unless the value is genuinely one-off and documented.
- Keep the type hierarchy small and unmistakable. Verify Russian text, long labels, dynamic values, and system text scaling before accepting a size.
- Use a consistent spacing rhythm. Optical alignment may require a small documented correction, especially for asymmetric icons and illustrated assets.
- Give nested surfaces coherent radii and separation. Use borders for grouping and focus, shadows for actual elevation, and avoid stacks of cards inside cards.
- Use semantic color roles for money, progress, warnings, success, locked states, and parent-only actions. Never encode meaning by color alone.
- Keep touch targets at least 48 by 48 logical pixels. A visible icon may be smaller while its hit area remains accessible and non-overlapping.
- Prefer clear, friendly feedback over reward noise. Avoid casino-like urgency, deceptive scarcity, shame, dark patterns, or animation that pressures a child to spend.
- Motion should explain cause, state, and spatial continuity. Respect reduced-motion settings and never use animation to hide latency.

Read [references/foundations.md](references/foundations.md) when defining or changing tokens, typography, spacing, components, responsive rules, imagery, or motion.

## Flutter implementation rules

- Compose safe areas intentionally and account for status/navigation bars, display cutouts, gesture insets, and the software keyboard.
- Use constraints and `LayoutBuilder` for structural adaptation. Use `MediaQuery` for device and accessibility inputs, not scattered width checks.
- Let text wrap and layouts reflow. Do not use `FittedBox`, global scaling, fixed heights, or clipped overflow to force essential text and controls into a screenshot-sized composition.
- Preserve system text scaling with `MediaQuery.textScalerOf(context)` unless a narrowly scoped exception is justified and tested.
- Keep tappable controls reachable with one hand where practical, but do not place destructive or high-stakes actions where accidental taps are likely.
- Design loading, success, empty, disabled, validation, transport-error, offline, and retry states as part of the component, not as late additions.
- Reuse project assets only when their visual direction is approved or the task explicitly requests them. Choose asset fit, crop, focal point, and contrast overlay deliberately.
- Add or change dependencies only when the approved design cannot be implemented cleanly with Flutter and the existing stack.

## Verification

Read [references/visual-qa.md](references/visual-qa.md) for the risk-based device, text-scale, state, accessibility, and screenshot matrix.

At minimum, verify:

- hierarchy and primary action are clear without relying on color;
- text does not clip, collide, or become unreadably small;
- controls meet target sizes and remain reachable with keyboard open;
- layouts survive narrow width, short height, and increased text scale;
- semantics and focus order match visual reading order;
- loading, empty, error, disabled, and retry states preserve layout stability;
- implementation uses the approved tokens and shared components;
- `flutter analyze`, relevant widget tests, and a real rendered-screen inspection pass.

Report what was visually inspected, the viewport and text scale used, any provisional decisions, and any states or devices not verified.
