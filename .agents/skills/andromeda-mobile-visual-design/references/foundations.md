# Visual Foundation Reference

Use these values as a starting frame for proposals, not as approved Andromeda tokens. The current product has no final visual system. Validate ranges against real Russian content, representative screens, target devices, and an approved direction before encoding them broadly.

## Foundation contract

Record an approved foundation with these groups:

1. Product direction: audience, tone, density, visual metaphor, and prohibited patterns.
2. Color roles: surfaces, content, brand/action, money, progress, success, caution, error, locked, and parent-only.
3. Typography roles: display, headline, title, body, label, caption, numeric value, and button.
4. Layout tokens: spacing, page gutters, section gaps, component padding, radii, control sizes, icon sizes, elevation, and dividers.
5. Component contracts: buttons, fields, cards, list rows, tabs, dialogs, feedback, balance displays, quest/progress elements, and bottom navigation.
6. Motion: durations, easing families, transition purpose, and reduced-motion behavior.
7. Responsive rules: supported widths, text scales, orientation, keyboard, and illustration behavior.

Prefer a few reusable roles over a large token catalog.

## Provisional dimensional baseline

Start on a 4-logical-pixel grid. A practical candidate spacing scale is:

`4, 8, 12, 16, 20, 24, 32, 40, 48, 64`

Use it semantically:

- 4–8: icon or tightly related inline separation;
- 8–16: internal component spacing;
- 16–24: page gutters and ordinary group spacing;
- 24–40: section separation;
- 48–64: major composition breaks used sparingly.

For phones, begin page gutters at 16 logical pixels on constrained widths and consider 20–24 when content and width allow. Do not shrink controls or type merely to preserve a wide gutter.

Interactive baselines:

- minimum hit area: 48 × 48 logical pixels;
- ordinary visible icons: usually 20–24 logical pixels inside the larger hit area;
- primary controls: usually 48–56 logical pixels high;
- compact controls still retain the full hit area even when their visible treatment is smaller.

Choose a short radius scale such as 8, 12, 16, and 24 rather than a different radius for every component. Nested shapes should appear optically concentric; adjust for padding and shape rather than applying a formula mechanically.

## Provisional typography baseline

Flutter font sizes use logical pixels and must remain compatible with system text scaling. For a child-readable starting proposal:

| Role | Starting range | Typical line height |
| --- | ---: | ---: |
| Metadata or compact caption | 12–14 | 1.3–1.5 |
| Supporting text and labels | 14–16 | 1.35–1.5 |
| Body and controls | 16–18 | 1.4–1.6 |
| Section title | 20–24 | 1.2–1.4 |
| Screen headline | 28–34 | 1.1–1.3 |
| Display or story accent | 36+ | Validate per composition |

Do not use small text to compensate for excess copy. Edit hierarchy or layout first. Use at most the number of font families the approved direction can justify; hierarchy should come primarily from size, weight, spacing, and color roles.

For balances, counters, timers, and changing numeric values, use stable-width numerals when the selected font supports them so the layout does not jump.

## Color and surface roles

Select colors by function and test them in the actual component state. At minimum:

- ordinary text against its surface meets 4.5:1 contrast;
- large text and essential UI boundaries meet 3:1 where the applicable accessibility rule allows it;
- disabled states remain legible and distinguishable without pretending to be enabled;
- success, error, progress, and wallet categories use iconography or text in addition to color;
- foreground content remains readable over illustration and photography.

Avoid generic generated-design defaults: decorative purple gradients, unnecessary glass surfaces, arbitrary neon, excessive rounding, or shadows on every container. A fairy-tale, game-like, or illustrated direction is acceptable only when it supports comprehension and the product's approved identity.

## Hierarchy and composition

Every screen should have one obvious primary task. Arrange content in this order unless the workflow requires otherwise:

1. orientation: where the user is and what changed;
2. decision-critical state: balance, progress, assignment, warning, or learning prompt;
3. primary action;
4. supporting detail and secondary actions;
5. decoration.

Keep illustrations out of the hit path and protect critical text from busy backgrounds. Define whether each asset contains, covers, crops, or anchors to a focal point. Do not let decorative art claim most of a short screen while functional content is scaled down.

## Role-sensitive design

Child-facing UI can be warmer, more visual, and more guided. It still needs clear numbers, honest consequences, and predictable controls.

Parent-facing UI can be denser and more analytical. Keep terminology, color meanings, and component behavior consistent with the child experience so the two roles describe the same system.

Do not make parental controls look like child rewards, and do not make spending actions more visually dominant than saving or planning merely to increase engagement.

## Motion baseline

Use motion tokens after the interaction model is stable. Reasonable proposal ranges are:

- direct press or state feedback: about 100–180 ms;
- small component transitions: about 160–240 ms;
- navigation or larger spatial transitions: about 220–350 ms.

Prefer opacity and transforms over layout-heavy animation. Exits are usually shorter than entrances. Disable non-essential movement under reduced-motion preferences and retain the state change without animation.

