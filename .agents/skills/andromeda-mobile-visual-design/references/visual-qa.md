# Mobile Visual QA

Use the smallest matrix that covers the affected composition, but never verify only the development device or a single screenshot.

## Direction status

Before judging visual consistency, state which status applies:

- **Draft:** no visual direction is approved; evaluate universal usability and label proposals.
- **Candidate:** a direction is being compared; evaluate it against the same content and device matrix as alternatives.
- **Approved:** tokens and components are the current source of truth; flag drift as a defect.

Do not create golden tests from Draft screens and call them the design baseline.

## Representative device matrix

Cover these logical-width classes when the changed screen can encounter them:

- 320: constrained or older phone;
- 360: common narrow Android phone;
- 412: common large Android phone;
- 600 or wider: tablet or expanded layout when supported.

Include at least one short-height device and one device with gesture navigation or system insets. Test portrait by default and landscape when the product supports it or the screen cannot safely assume portrait.

## Text and content matrix

- system text scale 1.0;
- a moderately enlarged scale around 1.3;
- a large accessibility scale up to 2.0 where the platform permits;
- longest realistic Russian labels and messages;
- zero, one-digit, and large balance or progress values;
- empty, loading, error, offline, disabled, success, and retry states;
- software keyboard visible for forms and bottom actions.

At large text scale, allow vertical growth and scrolling. Do not reduce user-selected text size, clip content, or hide the primary action behind the keyboard.

## Visual inspection checklist

### Hierarchy

- The primary task is recognizable within a few seconds.
- Important numeric values are distinguishable from labels and decoration.
- Primary and secondary actions are not visually equal.
- Parent-only, destructive, purchase, and irreversible actions have appropriate emphasis and confirmation.

### Typography

- Text roles are consistent and come from the theme.
- Line length, line height, and wrapping remain readable in Russian.
- No baseline collisions, orphaned short words caused by narrow controls, or truncated errors.
- Dynamic numbers do not cause distracting layout jumps.

### Spacing and geometry

- Repeated gaps use the approved rhythm.
- Alignment follows meaningful columns and baselines.
- Cards, dialogs, and controls use the intended radius and elevation roles.
- Nested surfaces do not create card-inside-card noise.
- Icons look optically centered, not merely mathematically centered.

### Interaction and accessibility

- Every interactive target is at least 48 × 48 logical pixels and targets do not overlap.
- Focus and semantics order follow the visual reading order.
- Icon-only controls have meaningful labels.
- Meaning is not communicated by color, motion, or illustration alone.
- Contrast is checked in actual states, including disabled and error states.
- Reduced-motion behavior preserves comprehension.

### Responsive behavior

- No overflow stripes, clipped text, accidental horizontal scrolling, or scaled-down essential UI.
- Safe areas and system insets do not cover content.
- The keyboard does not cover the active field, validation message, or submission action.
- Illustrations crop intentionally and never displace essential content on short screens.
- Loading and error states reserve enough space to avoid disruptive reflow.

## Verification methods

Use a combination appropriate to the change:

- render the actual Flutter screen on representative emulator sizes;
- capture screenshots for human comparison;
- use widget tests for overflow-sensitive states, semantics, and token usage where practical;
- add golden tests only after a direction is approved and the rendering environment is controlled;
- run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and relevant `flutter test` targets;
- build Android when fonts, assets, platform configuration, or release rendering changed.

## Review report

Report:

1. design status: Draft, Candidate, or Approved;
2. screens, components, states, viewport sizes, and text scales inspected;
3. approved tokens used and any provisional additions;
4. issues with file paths and the intended shared fix;
5. checks not run and the remaining visual risk.

