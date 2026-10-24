# Design Conventions

This document is the source of truth for visual decisions in the Flutter port.
It exists so new screens and components extend the existing language instead of
inventing a second one. When a rule here conflicts with a one-off screen, the
screen is wrong; update the shared token or pattern instead.

Related documents:

- [`BUTTONS.md`](BUTTONS.md) — every interactive control, its states and sizing.
- [`UI_PATTERNS.md`](UI_PATTERNS.md) — shell, header, sidebar, composer, overlays
  and the pattern checklist for new surfaces.
- [`COMPONENTS.md`](COMPONENTS.md) — component inventory and remaining stubs.

## 1. Golden rules

1. **Tokens first.** Colours, type sizes, spacing, radii, icon sizes, dimensions
   and durations come from `lib/core/theme.dart`. Do not hardcode a new value in
   a widget unless it is genuinely component-local geometry.
2. **One font, one default text colour.** DM Sans and `textPrimary` are owned by
   `ThemeData`. Normal text styles carry neither. Add a local colour only for a
   semantic exception (secondary, muted, hint, disabled, destructive, on-accent
   or code).
3. **Width decides layout.** Responsive behaviour uses the available width from
   `lib/core/responsive.dart`. Never check a device model, platform or physical
   screen size.
4. **Ink owns the full control area.** Any tappable surface is a `Material` with
   a clipped `InkWell`/`InkResponse`, so focus, hover, press and ripple feedback
   fill the button and cannot paint outside its rounded shape. There must be no
   decorative outer padding outside the ink surface: move that padding into the
   control itself, keeping the old overall size, so the effect never leaves a
   dead ring around a smaller highlight.
5. **Dark, quiet surfaces with one accent.** Blue is reserved for primary
   actions, focus, live audio and active state. Destructive actions are red;
   everything else is a neutral layer.
6. **No overflow at any supported width.** New layouts must survive 320 px, the
   600/840 px breakpoints, large text and the keyboard. Prefer `Flexible`,
   `Expanded`, `Wrap`, `FittedBox` or measured layouts over fixed rows that can
   exceed the viewport.
7. **Stubs stay honest.** A visible control that is not wired must say so or be
   disabled. Do not silently pretend a native runtime exists.

## 2. Token architecture

| Concern | Class | File | Notes |
| --- | --- | --- | --- |
| Palette and semantic colours | `KrithaColors` | `lib/core/theme.dart` | Includes background layers, text roles, brand accents, borders, bubbles, context menu and waveform |
| Type scale and shared styles | `KrithaText` | `lib/core/theme.dart` | Sizes, line heights, `body`, `message`, `composerInput`, `label` |
| Corner radii | `KrithaRadius` | `lib/core/theme.dart` | `xs` 4 through `xl2` 28, plus `full` |
| Spacing | `KrithaSpacing` | `lib/core/theme.dart` | 2–32; semantic aliases for screen/sidebar/message/composer |
| Component geometry | `KrithaDimensions` | `lib/core/theme.dart` | Header, composer, menu, Live Talk, waveform, sidebar, animation geometry |
| Motion | `KrithaMotion` | `lib/core/theme.dart` | Shared fast/normal/slow/composer/menu durations |
| Icons | `KrithaIcons` | `lib/core/theme.dart` | 14–28 px; Lucide is the icon family |
| Font family | `KrithaFonts` | `lib/core/theme.dart` | Bundled DM Sans only |
| Breakpoints | `KrithaBreakpoints`, `viewportOf` | `lib/core/responsive.dart` | Compact `< 600`, medium `600–< 840`, wide `≥ 840` |

`buildKrithaTheme()` applies the family once with `ThemeData.fontFamily` and
applies `textPrimary` to the generated text theme. `KrithaApp` merges
`Theme.of(context).textTheme.bodyMedium` at the top of the widget tree, so even a
`TextStyle` that omits family and colour inherits both. This is why component
styles must not repeat them.

[`KrithaColors`] is a static palette with light and dark values. `KrithaApp`
syncs it from the active theme in its `builder`, and every screen calls
`watchKrithaPalette(context)` at the start of `build` so a theme switch rebuilds
mounted subtrees immediately. Any new screen must do the same; otherwise its
cached token colours stay on the previous theme until the app restarts.

### Adding a token

Add a value to the narrowest existing class that owns the concern. If it is a
new semantic meaning rather than geometry, add it to `KrithaColors` with a
comment explaining the role. Do not create a second parallel token class.

## 3. Colour

### Background hierarchy

Use the darkest layer that still separates surfaces:

| Token | Use |
| --- | --- |
| `bgDeepest` | App/sidebar base, Live Talk pill interior |
| `bgBase` | Scaffold and canvas |
| `bgSurface` | Cards, sheets, settings sections |
| `bgPrimary` | Context menu and raised panels |
| `bgSecondary` | Header pills, circle controls, composer glass base |
| `bgTertiary` | Snackbars, chips, pressed/secondary surfaces |
| `bgQuaternary` | Scrollbar thumb and strong neutral fills |
| `bgCard` | Alternate card tint |
| `composerGlass` | Frosted composer fill (used through `KrithaGlassSurface`) |
| `bgScrim` | Drawer/dialog scrim |

### Text roles

| Token | Role | May be omitted? |
| --- | --- | --- |
| `textPrimary` | Default body, titles, menu labels, icon emphasis | Yes — inherited from theme |
| `textSecondary` | Icons, composer input, supporting but readable text | No — set locally |
| `textMuted` | Section labels, hints, disabled labels, metadata | No |
| `textDimmed` | Deep hints and very low-emphasis text | No |
| `textOnAccent` | Text/icons on blue or saturated fills | No |

The same rule applies to icons: `textPrimary`/`textSecondary` for normal icons,
`textMuted` for disabled, `error` for destructive, `textOnAccent` on primary
buttons.

### Accent and semantic colours

- `accentBlue` — primary action fill and selection.
- `accentLightBlue` — focus, cursors, live audio glow, selection handles.
- `accentSky`/`accentCyan`/`accentCyanDim`/`accentCyanBg` — supporting gradients
  and the Live Talk fluid glow.
- `success`, `warning`, `error` — status only. `error` is also the destructive
  text/icon colour.
- `waveformBar` — dictation metering bars. Intentionally light grey rather than
  pure white so the strip sits calmly in the frosted composer.

### Bubble and overlay colours

- User bubble: `userBubbleBg` with a full-radius shape and on-accent text.
- Assistant message: no bubble; normal transcript text on the background.
- Assistant actions/thinking/error surfaces: use the dedicated semantic tokens
  (`assistantBubbleBg`, `assistantBubbleBorder`, `thinkingBg`,
  `thinkingBorder`, `errorBubbleBg`, `ttsActiveBg`).
- Borders: `borderSubtle` for most surfaces, `borderFaint` for quiet separation,
  `borderStrong` for stronger outlines, `borderAccent` only for focused/active
  accent edges.
- Context menu press/focus overlay: `contextMenuPressed`; use it for menu rows
  and compact icon buttons so feedback is consistent. Menus never draw
  separator rules.

## 4. Typography

DM Sans is the only family. The bundled weights are 400, 500, 600 and 700.

| Style/token | Size | Weight / notes |
| --- | --- | --- |
| `size2xs` | 12 | Smallest incidental label |
| `sizeXs` | 13 | Section labels, metadata; often `w600`, `letterSpacing 1.1` |
| `sizeSm` | 15 | Snackbar and compact supporting copy |
| `sizeBase` | 17 | Default body and message text; line height `26` |
| `sizeComposer` | 17 | Composer input; line height `24` |
| `sizeMd` | 18 | Sidebar action labels, menu rows, sheet titles |
| `sizeLg` | 20 | Sidebar section titles |
| `sizeXl` | 22 | Prominent headings |
| `size2xl` | 26 | Large display text |
| `size3xl` | 30 | Hero/empty-state text |

Typography rules:

- Use `KrithaText.body`, `message`, `composerInput` or `label` where they fit;
  otherwise start from the scale and override only size/weight.
- Never add `fontFamily: 'DMSans'` in a feature widget.
- Never set `color: KrithaColors.textPrimary` on normal text. It is the default.
- Use `TextStyle` locally only for the semantic exceptions listed above, or for
  a deliberate weight/height/letter-spacing override.
- Bold is `FontWeight.w700` for menu labels, sidebar actions and section titles;
  `w600` is the default emphasis. Avoid using weight alone to signal state.
- Body line height is `1.55`; message and composer line heights stay at their
  token values so transcript spacing and composer measurement agree.
- Code blocks use the Dracula colours in `KrithaColors` and a monospace family
  only inside code rendering. That is the one intentional family exception.

## 5. Spacing, size and shape

- Use the spacing scale. `s16` is the default screen padding; `s24` is the
  sidebar gutter; `s8` is the standard gap between message blocks.
- Prefer `EdgeInsets.symmetric` with token values. If a component needs equal
  breathing room around an icon, put it inside the button's own sized box rather
  than around the button. Header icons use 12 px inner padding for a 48 px ink
  surface; there is no separate pill padding.
- Radii: `sm` for chips, `base` for inputs/small cards, `md` for panels, `lg` for
  primary buttons, `xl` for context menus/sheets/large panels, `xl2` for the
  expanded composer, `full` for capsules and circles.
- Icon sizes: `sm` 18 for compact inline icons, `base` 20 for standard actions,
  `md` 22 for sidebar circles, `lg` 24 for header/action icons and sidebar top
  actions, `xl` 28 for prominent empty-state icons.
- Standalone rows and circles use at least a 44×44 target: sidebar actions now
  56 px, session rows 56 px, round controls 44–48 px. The compact composer keeps
  its established 40×40 visual controls with an 8 px gap between the mic and the
  primary action; do not shrink that gap. Header icons are 48×48 ink surfaces
  with 12 px inner padding and no outer pill padding.

## 6. Responsive rules

```dart
final viewport = viewportOf(MediaQuery.sizeOf(context).width);
```

| Viewport | Width | Shell |
| --- | --- | --- |
| Compact | `< 600` | Overlay sidebar; compact composer; floating header |
| Medium | `600–< 840` | Overlay sidebar; compact composer; floating header |
| Wide | `≥ 840` | Docked 300 px sidebar; expanded composer; 760 px centred column |

Rules:

- The transcript/composer column is capped at `maxContentWidth` (760) and
  centred only on wide viewports.
- Compact layout must work at 320 px. Use the `tight` branch for control sizes
  where existing components do so; do not add another ad-hoc breakpoint.
- Height constraints matter: the composer grows up to `composerMaxHeight`, then
  scrolls internally. Sheets and menus must account for the keyboard insets.
- Avoid orientation checks. Landscape is just another width/height.

## 7. Surfaces, borders and elevation

- Default surface: fill + 1 px `borderSubtle` + slightly rounded corners. This
  is the house style for pills, menus, cards and buttons.
- Floating surfaces (menus, sheets, composer) get a soft dark shadow and a
  clipped `Material` so ink stays inside the shape.
- The composer uses `KrithaGlassSurface`: translucent fill, `BackdropFilter`
  blur, border and a soft lift shadow. Do not fake frost with a flat opacity.
- Headed overlays use `borderSubtle`; the header band uses a downward fade and
  blur instead of a hard divider.
- Scrims use `bgScrim`; never pure black unless the surface is explicitly
  `bgDeepest`.

## 8. Motion

Use `KrithaMotion`:

| Token | Duration | Use |
| --- | --- | --- |
| `fast` | 160 ms | Button/icon state changes |
| `normal` | 220 ms | Reveals and standard transitions |
| `slow` | 300 ms | Larger surface transitions |
| `composer` | 180 ms | Composer height/opacity |
| `contextMenu` | 180 ms | Menu fade + scale |

Animation rules:

- Animate opacity/transform, not layout, for overlays.
- Menus fade and scale from the corner nearest their anchor.
- Press feedback is immediate; do not animate the hit target.
- Live audio animations may repeat continuously while active, but must stop and
  settle into a dim static state when paused.
- `showGeneralDialog(requestFocus: false)` is required for menus that must not
  steal focus from the composer keyboard.

## 9. Accessibility and interaction

- Every icon-only control has a `Tooltip` and a semantic label where the icon is
  not self-explanatory.
- Rows that act as buttons set `Semantics(button: true)` where appropriate.
- Disabled controls are visibly dimmed (`Opacity` 0.5 or muted colour) and do not
  respond to taps.
- Focus, hover and pressed feedback must be visible on dark surfaces. Use the
  surface's `Material` ancestor, not a bare `GestureDetector`, for anything that
  looks like a button. Icon-only actions must set an explicit `focusColor` and
  `hoverColor` (normally `contextMenuPressed`) when the default theme highlight
  is too subtle.
- Never place an outer `Padding` around a button whose only purpose is visual
  breathing room. That padding must live inside the button's sized box so the
  ink surface fills the original footprint. Header icons are the reference:
  the old 4px pill inset moved into the icon button, producing a 48px ink
  surface with the same 48px pill height.
- Preserve focus when expanding the composer; do not dismiss the keyboard when
  opening a menu or selecting an attachment action.
- Do not use colour alone to communicate destructive/disabled state; pair it
  with a label or icon.

## 10. Change checklist

Before merging a new visual component:

- [ ] Values come from tokens, or the new token is documented here.
- [ ] No local `fontFamily` or default `textPrimary` colour.
- [ ] Tappable surfaces are `Material` + clipped `InkWell`/`InkResponse`.
- [ ] Ink feedback fills the control; no dead outer padding sits outside it.
- [ ] Hit target is at least 44 px (standalone) and matches the visible shape.
- [ ] Layout survives 320 px, 600 px, 840 px, large text and the IME.
- [ ] Menu/sheet anchoring accounts for safe areas and keyboard insets.
- [ ] Focus and press feedback are visible.
- [ ] Disabled/stub state is honest.
- [ ] `dart format`, `flutter analyze` and relevant widget tests pass.
- [ ] README and `docs/COMPONENTS.md` are updated if behaviour or geometry
      changed.
