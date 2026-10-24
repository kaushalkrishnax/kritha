# Button & Interaction Spec

This is the implementation guide for every tappable surface in Kritha. Use it
when adding a control so hit areas, ripples, colour and spacing match what is
already shipped.

> Visual tokens (colours, radii, spacing, type) are defined in
> [`DESIGN_CONVENTIONS.md`](DESIGN_CONVENTIONS.md) and `lib/core/theme.dart`.
> This document covers anatomy, states and composition.

## 1. Decision tree

| Need | Pattern | Example |
| --- | --- | --- |
| Primary action in a row | Blue 40 px rounded square | Send / Live Talk / stop |
| Secondary icon in a toolbar or pill | Transparent circular/rounded `InkWell` | Header icons, reply actions, docked sidebar search/collapse |
| Standalone round utility | 44–48 px circle on `bgSecondary`/`bgTertiary` | Drawer search, settings back, Live Talk controls |
| Full-width navigation row | 44–56 px row with `InkWell` | Sidebar actions and sessions |
| Menu command | 48 px context-menu row | Share, Pin, Archive, Delete |
| Message action surface | Bubble-shaped `Material` + `InkWell` | Long-press a user message |
| Destructive action | Same shape as its peer, `error` text/icon | Delete chat/message |
| Disabled/unavailable | Dim the normal shape; no tap handler | Camera, Plugins, Video |

Use a standard `IconButton` only for simple toolbar icons where its default
ripple is acceptable (`PlusButton`, `VoiceModeButton`). For a custom shape,
coloured fill, list row or full-bubble ripple, always build
`Material` + `InkWell`/`InkResponse`.

## 2. Shared button anatomy

```
Tooltip
  └─ Material (fill, shape, clip)
       └─ InkWell / InkResponse (onTap, shape, splash/overlay)
            └─ sized child (icon or label)
```

Rules:

- The `Material` must be the nearest ancestor of the ink widget; a transparent
  `Material(type: MaterialType.transparency)` is fine inside a decorated
  container.
- `clipBehavior: Clip.antiAlias` (or an explicit `borderRadius` on `InkWell`)
  keeps feedback inside rounded corners.
- The visible shape and the hit area must agree. Do not wrap a button in outer
  padding that leaves the focus/ripple smaller than the visual footprint. Move
  that space inside the button's sized box instead; the total size stays the
  same and the ink fills it.
- Icon-only controls always have a `Tooltip`; provide `Semantics(label:)` when
  the icon meaning is not obvious.
- Hover/focus/pressed states must remain visible on dark surfaces. Use
  `contextMenuPressed` for neutral overlays, or the default ink sparkle for
  accent fills.
- Disabled controls use `Opacity(0.5)` or a muted icon/text colour and a null
  callback.

## 3. Control inventory

### 3.1 Primary action — `ComposerActionButton`

**File:** `lib/features/chat/widgets/composer/composer_controls.dart`

| Property | Value |
| --- | --- |
| Size | 40 × 40 |
| Shape | Rounded square, `KrithaRadius.lg` (20) |
| Fill | `KrithaColors.accentBlue` |
| Icon | `textOnAccent`; 22 px compact, 18 px expanded |
| States | `ArrowUp02` when draft/content, square while busy, audio-lines when empty |
| Tooltip | “Send message”, “Stop response”, “Live Talk” |
| Motion | `AnimatedContainer` over `KrithaMotion.fast` for state colour/size changes |
| Gap from mic | `KrithaSpacing.s8` (8 px) |

The blue button is the only filled primary control in the composer. Do not add a
second blue fill in the same row. Busy uses the same blue surface with a square
glyph; it is not a separate destructive style.

### 3.2 Composer utility icons — `PlusButton`, `VoiceModeButton`

| Property | Value |
| --- | --- |
| Box | 40 × 40 |
| Icon | 24 px (`KrithaIcons.lg`), Lucide |
| Padding | `EdgeInsets.zero` inside `IconButton` |
| Plus colour | `textSecondary` |
| Mic colour | `textPrimary` |
| Tooltip | “Add attachments” / “Start dictation” |

These are intentionally visually lighter than the blue action. Keep them
transparent; only the primary action owns a fill.

### 3.3 Live Talk controls — `LiveTalkCircleButton`

| Property | Value |
| --- | --- |
| Size | 48 × 48; 42 × 42 when the row is tight (`< 340 px`) |
| Shape | `CircleBorder` with `borderSubtle` 1 px side |
| Fill | `bgTertiary` |
| Icon | 24 px, `textPrimary`; mic-off uses `textMuted` when paused |
| Tooltip | Video, Share screen, Pause/Resume Live Talk, End Live Talk |
| Ripple | Circular `InkWell`, clipped by the `Material` shape |

The glowing centre pill is not a button; it is the `LiveTalkPill` status surface.
See [`UI_PATTERNS.md`](UI_PATTERNS.md#6-live-talk).

### 3.4 Header pill controls — `_HeaderPill` / `_HeaderIcon`

| Property | Value |
| --- | --- |
| Pill fill | `bgSecondary` |
| Pill shape | `KrithaRadius.full`, 1 px `borderSubtle`, clipped |
| Pill padding | **None** — buttons own the full pill height |
| Icon control | 24 px icon + 12 px padding = 48 × 48 |
| Focus/press surface | The full 48 × 48 icon control |
| Ripple | `InkWell` radius 20, `contextMenuPressed` splash/highlight/focus/hover |
| Spacing | 4 px between icons |

The outer pill may contain a single icon or a group. There is deliberately no
outer `Padding`: the former 4 px inset now lives inside each icon's own 48 px
sized box. Focus and ripple feedback therefore fill the capsule height instead
of showing a smaller rounded highlight with a dead ring around it. Keep the
12 px icon padding equal on all sides.

### 3.5 Standalone circles — `_CircleIconButton`

| Property | Value |
| --- | --- |
| Size | 44 × 44 |
| Shape | `CircleBorder` + `borderSubtle` |
| Fill | `bgSecondary` |
| Icon | 22 px (`KrithaIcons.md`), `textPrimary` |
| Tooltip | Required |
| Ripple | `InkWell` with `customBorder: CircleBorder()` |

Used for the sidebar search control. Settings uses the same circle with an
`InkResponse` (see 3.8).

### 3.6 Sidebar action rows — `_ActionRow`

| Property | Value |
| --- | --- |
| Height | 56 px (`sidebarActionRowHeight`) |
| Horizontal padding | `KrithaSpacing.s24` |
| Icon | 24 px, Lucide 600 weight (`LucideIcons600`), `textPrimary` |
| Icon–label gap | `KrithaSpacing.s14` |
| Label | 18 px, `FontWeight.w700`, ellipsis at one line |
| Row gap | **None** — top actions stack contiguously |
| Ripple | Full-row `InkWell`; no separate inner padding surface |

Icons for these six actions must use the 600-weight Lucide set and 24 px so they
match the visual weight of the labels. Do not reintroduce 2–4 px vertical gaps
between rows; the 56 px row is the rhythm, matching the relaxed reference
sidebar rather than the earlier tighter 44 px list.

### 3.7 Sidebar session rows — `_SessionRow`

| Property | Value |
| --- | --- |
| Height | 56 px |
| Horizontal padding | `KrithaSpacing.s24` |
| Selected fill | `bgPrimary` |
| Unselected fill | Transparent |
| Interaction | Tap to switch; long-press for the session menu |
| Ripple | Full-row `InkWell` inside `Material` |

The long-press menu opens at the pointer position (captured by a `Listener`) and
clamps inside the sidebar. Do not use a hamburger/ellipsis on the row; the
long-press is the affordance.

### 3.8 Settings back — `_SettingsHeader` back control

| Property | Value |
| --- | --- |
| Size | 44 × 44 |
| Shape | `CircleBorder` + `borderSubtle` |
| Fill | `bgSecondary` |
| Icon | 20 px chevron, `textSecondary` |
| Ink | `InkResponse`, `customBorder: CircleBorder()`, `containedInkWell: true` |
| Padding | **Zero inside the Material** — the 44 px box is the ripple surface |

The ripple/focus highlight must fill the whole circle. If you wrap the icon in
an `IconButton`, remove its internal padding/constraints or the feedback shrinks
to an inner rectangle.

### 3.9 Context-menu rows — `_MenuItemRow`

| Property | Value |
| --- | --- |
| Menu width | 200 px |
| Row height | 48 px; first/last rows are 56 px |
| Horizontal padding | `KrithaSpacing.s20` |
| Vertical padding | Owned entirely by the row; first/last rows include an 8 px outer edge inset, with no menu-level gutter |
| Icon column | 24 px, icon 18 px, gap 16 px |
| Label | 18 px, `FontWeight.w700`, one line, ellipsis |
| Press feedback | `contextMenuPressed` overlay, `NoSplash` |
| Disabled | `Opacity(0.5)`, no tap handler |
| Destructive | `KrithaColors.error` for icon and label |

The whole row is the hit target, including the first/last row's 8 px outer edge
inset, so press feedback fills the surface edge to edge. That inset gives the
top and bottom rows extra breathing room around the clipped 24 px corners
without dead bands. Middle rows stay 48 px. Menus never draw horizontal
separator rules; group emphasis comes from the row rhythm and destructive
colour. Do not add surface padding, row margins or `<hr>`-style dividers.

### 3.10 User message bubble — `UserMessage`

| Property | Value |
| --- | --- |
| Fill | `userBubbleBg` |
| Shape | `KrithaRadius.xl` (24), fully clipped |
| Padding | 20 px horizontal, 12 px vertical |
| Interaction | Long-press opens Copy/Edit menu |
| Ripple | `contextMenuPressed` splash/highlight via full-bubble `InkWell` |

The bubble itself is the button surface. Do not put a separate tiny copy icon
inside it; long-press is the menu gesture.

### 3.11 Reply actions — `_ActionIcon`

| Property | Value |
| --- | --- |
| Icon | 20 px |
| Padding | 8 px on all sides (36 px ink surface) |
| Colour | `iconMuted` by default |
| Tooltip | Copy, Read aloud, Share reply, More actions |
| Ripple | Transparent `Material` + rounded `InkWell`, radius 20 |
| Feedback | `contextMenuPressed` splash, highlight, focus and hover |
| Gap | 2 px between actions |

These sit under an assistant reply and should stay visually quiet, but their
focus/click feedback must still be visible. Each icon owns a transparent
`Material` so the ink surface is fully clipped and filled; there is no outer
padding outside the ink. Copy may switch to a confirmation label; Read aloud
uses the TTS/active colour while speaking. More is a labelled stub that reports
the missing response menu.

### 3.12 Scroll-to-bottom — `_ScrollDownButton`

| Property | Value |
| --- | --- |
| Size | 45 × 45 |
| Shape | Circle |
| Fill | `scrollDownSurface` (translucent `bgTertiary`, lighter white in light mode) |
| Border | 1 px `borderSubtle` |
| Elevation | 4, shadow `composerShadow` |
| Icon | `ArrowDown02`, 24 px `textPrimary` |
| Visibility | Fade over 180 ms; auto-hide after 1.5 s; ignore pointer when hidden |

It floats above the composer with 24 px lift and 12 px bottom gap. Keep it
outside the transcript's hit area so it never blocks message taps.

## 4. State matrix

| State | Visual | Interaction |
| --- | --- | --- |
| Default | Normal fill/icon; 1 px subtle border where appropriate | Tap enabled |
| Hover | Subtle neutral overlay / default hover colour | Pointer cursor where applicable |
| Focus | Visible focus highlight on the whole shape | Keyboard activation enabled |
| Pressed | `contextMenuPressed`/splash inside the shape | Tap callback fires on release |
| Busy | Primary button swaps glyph; label/tooltip updates | Tap stops the current response |
| Disabled | 50% opacity or muted colour; no fill emphasis | Null callback, no ripple |
| Destructive | `error` text/icon; same shape as peers | Confirmation or direct destructive action |

Do not use a colour change as the only pressed indicator. Every interactive
surface needs a visible ripple/overlay or a state change.

## 5. Adding a new button

1. Pick the pattern from §1; do not invent a new size or fill.
2. Use `KrithaDimensions` for the control size and `KrithaRadius` for its shape.
3. Build `Material` → `InkWell`/`InkResponse`; clip to the shape.
4. Add a `Tooltip`; add `Semantics(button: true, label: ...)` for icon-only or
   ambiguous controls.
5. Verify the shape is fully covered by feedback. Standalone controls use a
   44×44+ target; compact composer controls keep the established 40×40 size and
   8 px mic-to-primary gap.
6. Check default, focus, pressed, busy and disabled states.
7. Test at 320 px, 600 px and 840 px, with the keyboard open where relevant.
8. Update this document and [`COMPONENTS.md`](COMPONENTS.md) if the control is
   part of the shared inventory.
