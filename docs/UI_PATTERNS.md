# UI Patterns

This document describes how Kritha's surfaces are composed and how they behave.
It is the companion to [`DESIGN_CONVENTIONS.md`](DESIGN_CONVENTIONS.md) (tokens
and visual rules) and [`BUTTONS.md`](BUTTONS.md) (control anatomy). Use it as a
blueprint when adding a screen, panel, overlay or composer state.

## 1. Shell

```
ChatScreen
  ├─ Sidebar (docked on wide, overlay drawer below 840)
  ├─ Transcript (header band fades over it; composer floats over it)
  ├─ Floating header (sidebar/menu, new chat, chat options)
  ├─ Floating composer stack (attachments, edit warning, capsule/expanded)
  └─ Scroll-to-bottom affordance
```

Rules:

- The shell is width-driven: compact/medium use an overlay drawer, wide uses a
  docked 300 px sidebar. There are no device or platform checks.
- The transcript owns the full height. The header and composer are overlays, not
  layout rows; the message list reserves the measured composer height and top
  content padding so content can scroll clear.
- The readable column is capped at 760 px and centred only on wide screens.
- Every screen should work at 320 px wide and with the IME open.

## 2. Header

- Floating band: 100 px tall, backdrop blur, downward fade and subtle scrim. No
  hard divider.
- Compact header: sidebar button, new chat and per-chat ellipsis. Branding lives
  in the sidebar, not the compact chat header.
- Wide/medium header: the same action pills, with the per-chat title where the
  layout has room.
- Pills are `Material` + `InkWell` groups with no outer padding. Each icon uses
  12 px inner padding, making a 48 px ink surface that fills the pill height
  (see [`BUTTONS.md`](BUTTONS.md)). The former 4 px pill inset moved into the
  button; do not reintroduce a dead ring around the focus highlight.
- The ellipsis opens the shared context menu aligned to the button. Share,
  Pin/Unpin, Uploaded files, Find in chat, Archive and Delete live there.
- Header icons must show both press and focus feedback; the pill's clip keeps
  the ripple inside the capsule.

### Workspace headers

Workspace screens use the shared borderless back control. Back navigation pops
the current route so it returns to the screen that opened it; Android system
back and desktop Escape use the same stack. When there is no previous route the
action delegates to the platform's normal exit behavior. Do not hard-code a
destination such as `/chat` in a back handler.

Workspace action rows keep natural widths. Place quiet utility actions on the
left and the single primary action on the right; never expand actions to fill
the row. `WorkspaceOutlinedAction` labels stay single-line with ellipsis.

### Response actions

Assistant replies end with a quiet action row: Copy, Read aloud, Share and More.
Each 20 px icon sits in an 8 px transparent `Material` + `InkWell`, uses
`contextMenuPressed` for splash/highlight/focus/hover, and has a tooltip. There
is no padding outside the ink surface. More is a labelled stub; keep the order
and 2 px gaps stable.

## 3. Sidebar

### Geometry

| Mode | Width | Notes |
| --- | --- | --- |
| Wide | 300 px docked; 56 px when collapsed | Collapsible rail stays visible |
| Compact/medium | 78% of width, max 340 px | Overlay drawer with backdrop and edge swipe |

### Structure

1. Header: brand, search control and desktop collapse control. On the docked
   desktop sidebar both trailing controls are borderless (hover fill only); the
   overlay drawer keeps the search circle and sits it flush with the panel edge
   when no collapse control follows.
2. `New chat`, `Library`, `Models`, `Providers`, `Plugins`, `More`: 56 px rows,
   24 px gutter, no inter-row gaps.
3. Optional Pinned section.
4. Recents section and 56 px session rows.
5. Footer account avatar/name; its menu contains account actions and Settings.

Rules:

- Top action icons use Lucide 600 at 24 px and sit beside 18 px `w700` labels.
- Rows are full-width hit targets. Selected sessions use `bgPrimary`; unselected
  rows are transparent.
- Long-press a session on touch, or right-click it with a mouse, for Pin/Unpin,
  Rename, Archive and Delete. The menu opens at the press point and clamps
  inside the sidebar.
- The collapsed wide-screen rail shows `LayoutAlignLeft` (expand), New chat,
  Library, Models, Providers, Plugins and More, then the account avatar at the
  bottom. Archived chats and Permissions live under Settings → Privacy.
  The full sidebar header pairs borderless search and `PanelLeft` collapse
  controls; the compact chat header uses `MenuTwoLine` to open the drawer.
- Wide-screen open/close animates the 56↔300 px panel with a clipped width
  transition plus a short cross-fade; keep it fast but never a snap.
- Do not add a drawer close icon; the backdrop and edge swipe close it.
- Archived chats use a dialog with restore/delete actions; do not build a second
  sidebar mode unless the design changes.

## 4. Composer

### 4.1 Layers

The composer is a floating stack:

```
edit warning (optional)
attachment preview strip (optional)
KrithaGlassSurface
  ├─ compact: plus | text field | mic | primary action
  └─ expanded: text field
                plus | spacer | mic | primary action
```

- Frost: translucent fill, 18 px `BackdropFilter`, border and lift shadow via
  `KrithaGlassSurface`.
- Soft scrim/fade above the capsule; no hard edge against the transcript.
- Attachment previews use `bgTertiary`; their remove-X control uses the next
  surface step, `bgQuaternary`, so it stays legible over both images and files
  without reading as a pure-black cut-out.
- The message list measures the composer and adds bottom padding so the final
  turn can scroll above it.

### 4.2 Expanded vs compact

| State | Trigger | Layout |
| --- | --- | --- |
| Compact | Empty/focused capsule in compact/medium | One row, 58 px capsule, controls 40 px |
| Expanded | Second line, any attachment, or wide viewport | Multi-line field + 44 px bottom row, min height 116 px |

- Expansion is immediate (no height animation) and keeps focus/selection.
- The input is multiline; Enter inserts a newline. The field scrolls internally
  past `composerMaxLines` and the shell never overflows.
- The mic and primary blue action are separated by `KrithaSpacing.s8`. Do not
  reduce that gap; on compact screens the text field absorbs the difference.
- `showGeneralDialog(requestFocus: false)` is used for menus so the keyboard does
  not drop when an attachment menu opens.

### 4.3 Primary action

The 40 px blue action changes meaning with state:

- Content present → send (`arrowUp`).
- Empty → Live Talk (`audioLines`).
- Reply in flight → stop (`square`).

Only one primary fill is allowed in the composer row. Busy is not destructive;
it keeps the blue surface and changes the glyph.

### 4.4 Editing warning

When editing an earlier user message, show the closable warning above the
capsule: “Editing this message will restart the conversation from here.” The X
clears the draft/edit state. Sending deletes the edited turn and every later
turn, then appends the replacement and a fresh reply. Do not branch history.

## 5. Dictation strip

`DictationBar` replaces the normal composer while `dictationProvider` is active.

```
[ X cancel ]   [ live waveform ]   [ square stop ]   [ arrow send ]
```

- Real microphone capture and amplitude metering.
- Cancel discards; square stops and shows “Transcribing…”; arrow stops,
  transcribes, then sends.
- The transcribe seam reports a missing local model; no audio is attached to the
  message. This is an explicit stub, not a silent failure.
- No overflow at 320 px; the waveform takes the flexible middle space.
- Keyboard focus is irrelevant while recording; keep the strip above the safe
  area and respect bottom insets.

### Waveform spec

`RecordingWaveform` is the Flexiyo-derived meter:

| Property | Value |
| --- | --- |
| Direction | Newest amplitudes on the right |
| Bars | 3 px wide, 4 px gap, 42 bar cap |
| Height | 26 px; older/paused slots fade to 0.12 |
| Radius | Half the bar width (rounded ends) |
| Colour | `KrithaColors.waveformBar` — light grey, not pure white |
| Paused | Animation stops and bars fade in place |
| Responsive | Fitting bar count is computed from available width, minimum 10 |

The light grey and thicker 3 px bars match the reference recording strip. Do not
switch back to `textPrimary` or 2.4 px bars.

## 6. Live Talk

### State machine

`ComposerState` transitions through `LiveTalkPhase`: listening, paused, speaking
and related processing states. The bar exposes Video, Share screen, the centre
status pill, pause/resume microphone and end. Video and screen share are labelled
stubs; no STT/TTS runtime is bundled.

### Layout

```
[ video ] [ share ]   [ glowing pill ]   [ mic ] [ close ]
```

- Four round controls (48 px, 42 px under 340 px) with 6–8 px gaps.
- The pill is `Expanded` + `Center`, so it stays in the middle and never
  collapses. It has a 50 px height, 120 px max width and is tinted by the
  available width at 320 px.
- The mic shows `mic` while listening and `micOff` while paused.
- Pause/resume and end are real state transitions; nothing pretends to
  transcribe.

### Glowing pill

`LiveTalkPill` (`lib/features/chat/widgets/composer/live_talk_pill.dart`) keeps
the brand gradient palette but renders it as a fluid listening surface:

- Three soft radial blue/cyan blobs drift at different frequencies and blend
  additively inside the clipped capsule.
- A thin audio-level wave moves across the middle; its amplitude and opacity
  breathe with the flow.
- Listening/speaking phases animate on a 2.4 s loop. Paused stops the controller
  and settles at a dim 0.3 progress, so the pill remains visible but quiet.
- The motion is **visual only** while the native Live Talk runtime is absent.
  When microphone levels become available, drive the same painter from the real
  level instead of adding a second indicator.
- Keep the geometry dark and restrained; the pill is the only place in the
  composer that uses the additive glow.

## 7. Shared context menu

`showKrithaContextMenu` is the only menu implementation. Do not build bespoke
popup menus.

### Geometry

| Property | Value |
| --- | --- |
| Width | 200 px |
| Row height | 48 px; the last row is 56 px with an 8 px bottom inset. Without a header the first row is also 56 px |
| Corner radius | 24 px (`KrithaRadius.xl`) |
| Surface | `bgPrimary`, `borderSubtle`, 24 px `menuShadow` |
| Row padding | 20 px horizontal; the first/last row also owns the 8 px outer edge inset |
| Icon | 18 px in a 24 px column; 16 px icon-to-label gap |
| Label | 18 px, `FontWeight.w700`, one line, ellipsis |
| Menu-level vertical padding | **None** |
| Separators | **None** — no horizontal rules or divider lines |
| Header (optional) | 55 px high, 20/20/20/8 padding: the 8 px top edge inset belongs to the header, so the first action row stays 48 px |
| Anchor gap | 8 px |
| Screen margin | 12 px on all sides; safe top 16 px |
| Surface width | 200 px default; panel-bound menus may fill the panel minus the 12 px margin |

### Behaviour

- Fade + scale from the corner nearest the anchor over 180 ms.
- Clamp inside the screen and sidebar bounds; with the keyboard visible, clamp
  fully above the IME.
- The menu owns a 12 px inset on every side, for screen- and panel-bound menus
  alike. Panel bounds keep it inside a sidebar without inheriting the row's
  padding, and right-aligned menus meet their anchor's right edge instead of
  the viewport's.
- `requestFocus: false` so the composer keyboard stays up.
- `NoSplash` with a `contextMenuPressed` overlay for menu rows; no ripple leaks
  past the rounded surface. `ContextMenuItem.focusColor` overrides the overlay
  for a single row (destructive rows pass a translucent red) and never derives
  it from the label colour automatically.
- Full row is tappable and fills the surface edge to edge. The outer 8 px inset
  lives on the first/last row, or on the header when one is present, so the
  content clears the rounded corners without a menu-level gutter or separator.
- Disabled rows are dimmed and inert. Destructive rows use `error` (the real
  destructive red) for both icon and label.
- Headed menus: user-message time, chat title. Headerless: attachment picker,
  session actions and the sidebar account menu start directly with their first
  56 px edge row.
- On desktop, session rows and message bubbles open the same menu on right
  click; touch keeps long-press.

### Anchors

| Menu | Anchor | Alignment |
| --- | --- | --- |
| Attachment picker | Plus button | Below, clamped |
| Header ellipsis | Ellipsis button | Right-aligned |
| User message | Long-press or right-click point/bubble | Right edge flush with the bubble, not the viewport |
| Sidebar session | Long-press or right-click point | Clamped inside sidebar |
| Sidebar account | Footer avatar/name row, fixed | Sized to the sidebar with its own 12 px inset, flips above near the bottom edge |

## 8. Dialogs, sheets and snackbars

- Dialogs follow the active light/dark theme, `bgSurface`/`bgPrimary`, 24 px
  corners and a scrim. Destructive actions are red and explicit.
- Bottom sheets use `bgSurface`, no surface tint, 24 px top corners.
- Snackbars are floating, `bgTertiary`, 12 px corners, 15 px text; use them for
  transient confirmations and labelled stub messages.
- Do not use a snackbar for a blocking decision (archive/delete/reset); use a
  dialog or menu.
- Dialogs that contain a text field should autofocus it and keep Save/Cancel in
  the standard trailing order. Use `KrithaInputs.decoration` so the field has a
  visible `borderSubtle` outline and a `borderAccent` focus outline; never leave
  a popup input borderless.

## 9. Keyboard and focus

- Keep composer focus across expansion and menu opening.
- Android back while the IME is open dismisses the keyboard first; the next back
  follows normal route behaviour.
- Menus and sheets clamp above the IME.
- Do not move focus to a menu on open; menu navigation is pointer/touch driven.
- After sending, the composer retains focus unless a dialog/route change
  explicitly takes it.

## 10. Empty, error and stub states

- Empty chat: centred logo/icon on a quiet raised tile, short title and body,
  no fake suggestions that cannot work.
- Runtime errors: show the message inline or in a snackbar with a clear next
  step. Do not swallow exceptions.
- Stubs: label the action and report “not available in this build” (snackbar or
  disabled row). Visible stubs in the current build include Camera, Plugins,
  Think harder, Library, More, chat search, Permissions, read aloud, video and
  screen sharing.
- Missing local STT/TTS models should be explicit; do not fabricate a
  transcript.
- Loading a workspace list or a detail surface uses a layout-shaped skeleton
  (`SkeletonBox`), not a centred spinner. Prefer skeletons for every
  screen/list/detail load. They mirror the real card or section geometry so the
  swap does not move content. Do not skeletonize individual small elements such
  as buttons, labels, icons or inline counts; those keep their normal chrome and
  only use a spinner for an in-place action. Short in-place work such as
  pagination and connection tests keeps its compact spinner.

## 11. Motion and feedback

| Interaction | Motion |
| --- | --- |
| Header/menu press | Immediate ink overlay; menu 180 ms fade + scale |
| Composer expansion | Immediate layout switch; no size animation |
| Composer action state | `AnimatedContainer` 160 ms |
| Scroll-down reveal | 180 ms fade; auto-hide 1.5 s |
| Dictation waveform | Live meter; paused fade in place |
| Live Talk pill | 2.4 s fluid loop; paused settles to dim static |
| Skeleton loading | 1.2 s left-to-right shimmer sweep; stops when data arrives |

Do not animate layout for the composer expansion or menu position. Respect the
existing durations; add a new `KrithaMotion` token only if the interaction is a
new class of motion.

## 12. Models and providers workspaces

### Model list

- Cards are compact rows: publisher avatar (or initials fallback), repository
  name, publisher, then task/parameter/updated/download/like metadata. The Hub
  search payload has no avatar field, so resolve it once per publisher and cache
  the result; never request it per card rebuild.
- The first load renders `CatalogueSkeleton` cards that mirror the real card
  height. Keep the inline spinner for appended pages, and show Load more only
  while a cursor exists.
- The search field keeps the sort menu and a filter action side by side, with
  the filter icon using the same muted treatment as sorting. The filter popup
  is keyword-only: presets such as `litert-lm` are toggleable chips that cannot
  be deleted, and user keywords can be added or removed. The default request
  applies the preset `filter=litert-lm` tag; the key is never shown in the
  popup.

### Model details

- Header: shared back control, the title “Model Details” and one overflow menu
  with Open in HF Hub and Copy repository URL. Use
  `HugeIcons.strokeRoundedLinkSquare02` for Open in HF Hub.
- Overview: publisher logo, repository identity and a copy action. The card sits
  first with no section title. Render the
  `namespace/` prefix as a muted run and the model name as its own run so a wrap
  moves the whole name to the next line instead of splitting it. Below it,
  followers, then likes, then downloads. Do not reintroduce a separate publisher
  heading or verification mark.
- Metadata chips: Tasks (`error`), Libraries (`accentLightBlue`), Languages
  (`success`), Licenses (`textPrimary`) and Other (`textMuted`, no icon). Show
  the exact Hub tag value; a normalized copy (case and separators ignored) is
  for comparison only, never for display. Long labels ellipsize inside the chip
  instead of overflowing.
- Languages: one language renders directly; two or more collapse to an
  “N languages” chip. Expansion is one-way for that visit. Do not add group
  filter chips above the tags.
- Setup: published technical facts only, an instruction of at most 20 words and
  a primary action to Active Models. No memory or storage compatibility
  estimates.
- Card and files: Markdown with View more/View less and an honest empty state.
  The Model Card title carries copy and ellipsis actions; the menu offers
  Download (saves the Markdown) and Open Raw (raw Hub URL). Files show the
  branch, a clickable latest commit, sizes and a six-row View more. Links open
  the Hub externally.

### Provider cards

- The first settings load renders provider-shaped skeleton cards instead of a
  centred spinner; only the list is skeletonized, not each action button.
- One natural-width action row per card: Test + Usage on the left, Connect or
  Configure on the right. Do not wrap actions in `Expanded` or flex.
- Test and Usage are always visible but disabled until the provider has its
  required credentials. Connect is the only filled (primary) action; Configure
  uses the same neutral outlined treatment as Test/Usage.
- Usage counts are local. Label the popup as tracked on this device and never
  fabricate spend or remote billing values.

## 13. Pattern checklist for new surfaces

- [ ] Does the surface use the background hierarchy and `borderSubtle`?
- [ ] Are all text styles free of local font family/default primary colour?
- [ ] Are taps on `Material` + clipped `InkWell`/`InkResponse`, with visible
      focus/hover/press feedback?
- [ ] Does the ink surface fill the control, with no decorative outer padding
      leaving a dead ring?
- [ ] Are standalone hit targets ≥44 px and full-row where the row looks
      tappable? Compact composer controls keep their 40 px size and 8 px
      mic-to-primary gap.
- [ ] Does it survive 320 px, the 600/840 breakpoints, large text and the IME?
- [ ] Does it clamp to safe areas and above the keyboard?
- [ ] Are menus using `showKrithaContextMenu` rather than a new popup?
- [ ] Is the primary action the only blue fill in its row?
- [ ] Are disabled/stub actions visibly disabled or labelled?
- [ ] Is motion using `KrithaMotion` and stopped when inactive?
- [ ] Are `dart format`, `flutter analyze`, tests and both builds still green?
- [ ] Did you update README, `COMPONENTS.md` and this document if the pattern
      changed?
