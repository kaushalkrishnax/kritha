<div align="center">

<img src="assets/images/kritha_logo.png" alt="Kritha app icon" width="104" height="104" />

# Kritha

### A Voice-First, Privacy-First On-Device Assistant Foundation

**Your device. Your data. A local-first assistant, built for Android, iOS and desktop.**

<p>
  <a href="https://github.com/kaushalkrishnax/kritha"><img src="https://img.shields.io/github/stars/kaushalkrishnax/kritha?label=Stars&color=FAFBFC&style=flat-square" alt="GitHub stars" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-10B981?style=flat-square" alt="MIT license" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.7-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter 3.47.7" />
  <img src="https://img.shields.io/badge/Dart-3.13.5-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart 3.13.5" />
</p>

<p>
  <img src="https://img.shields.io/badge/Android-arm64%20%7C%20x86__64-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android arm64 and x86_64" />
  <img src="https://img.shields.io/badge/iOS-arm64-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS arm64" />
  <img src="https://img.shields.io/badge/macOS-universal-000000?style=flat-square&logo=apple&logoColor=white" alt="Universal macOS" />
  <img src="https://img.shields.io/badge/Windows-x86__64-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows x86_64" />
</p>

</div>

---

### Contents

- [Release packages](#release-packages)
- [Highlights](#highlights)
- [Platform targets](#platform-targets)
- [Quick start](#getting-started)
- [Signed release builds](#signed-release-builds)
- [Workers and runtime packs](#workers-and-runtime-packs)
- [What is implemented](#what-is-implemented)
- [Verification](#verification)
- [Documentation](#documentation)
- [License](#license)

---

## Overview

Kritha is a local-first assistant foundation porting the conversation experience
from the original React Native app into Flutter. It includes a responsive chat
shell, adaptive composer, dictation/wake-word foundation and persistent local
history. Chat sessions can be created, switched, pinned, renamed, archived,
restored and deleted; the first prompt in a chat creates its title.

The base app does **not** bundle LLM or speech-model weights. Android runtime
engines are delivered separately in an installable local runtime pack. There is
no hosted chat backend in this Flutter foundation; release/runtime Workers only
serve metadata and signed Android runtime artifacts.

## Release packages

Builds are produced locally under `dist/` (not committed to Git). Android APKs
are split per architecture; app stores receive bundles/archives appropriate to
their platform.

| Platform artifact | Architecture | Local filename pattern |
| --- | --- | --- |
| Android APK | `arm64-v8a` | `Kritha-<version>-arm64-v8a-RELEASE.apk` |
| Android APK | `x86_64` | `Kritha-<version>-x86_64-RELEASE.apk` |
| Android App Bundle | Both Android ABIs | `Kritha-<version>-universal-RELEASE.aab` |
| iOS App Store IPA | `arm64` device | `Kritha-<version>-arm64-RELEASE.ipa` |
| macOS app | `arm64` | `Kritha-<version>-arm64-RELEASE.app` |
| macOS app | `x86_64` | `Kritha-<version>-x86_64-RELEASE.app` |
| Windows archive | `x86_64` | `Kritha-<version>-x86_64-RELEASE.zip` |

The iOS App Store does not accept simulator slices in its device IPA. The
`x86_64` iOS simulator slice is for simulator testing only.

## Highlights

<div align="center">
  <table>
    <tr>
      <td width="50%" align="center"><br/>💬<h3>Adaptive conversation UI</h3><sub>Responsive chat shell, persistent sessions, keyboard-aware composer and shared context menus.</sub><br/><br/></td>
      <td width="50%" align="center"><br/>🎙️<h3>Voice-ready Android</h3><sub>Wake-word foreground service and on-demand runtime pack for LiteRT-LM and sherpa ONNX.</sub><br/><br/></td>
    </tr>
    <tr>
      <td width="50%" align="center"><br/>📦<h3>Optional local runtimes</h3><sub>Install both Android runtime modules together; model weights remain separately managed.</sub><br/><br/></td>
      <td width="50%" align="center"><br/>🖥️<h3>One Flutter codebase</h3><sub>Android, iOS, separate arm64/x86_64 macOS apps and Windows x86_64 platform foundations.</sub><br/><br/></td>
    </tr>
  </table>
</div>

## Requirements

- Flutter 3.47.7 stable / Dart 3.13.5 (the versions this was verified against)
- Xcode for iOS/macOS builds, Android SDK for Android builds, and Visual Studio
  2022 with the Desktop development with C++ workload for Windows builds

## Platform targets

| Platform | Architectures | Notes |
| --- | --- | --- |
| Android | `arm64-v8a`, `x86_64` | 32-bit ABIs are filtered out of both the app and plugin AARs |
| iOS | `arm64` | Device build; simulator build uses the host architecture |
| macOS | `arm64`, `x86_64` | Universal release app (deployment target 12.0) |
| Windows | `x86_64` | Native Windows 10/11 desktop build from a Windows x64 host |

The shared Flutter UI, theme, SQLite history and composer run on every target.
Platform folders for Android, iOS, macOS and Windows are checked in; there is no
web or Linux target in this foundation. Windows x64 release builds run from a
Windows host with Visual Studio 2022 and the Desktop development with C++ workload.

Launcher icons for every target are generated from the checked-in brand sources
with:

```sh
./tool/generate_app_icons.sh
```

The script writes Android legacy + adaptive icons (including monochrome),
the full iOS and macOS asset catalogues, and the multi-resolution Windows `.ico`.
Run it from the repository root after changing `assets/images/kritha_app_icon.png`
or the adaptive foreground/background/monochrome sources.

## Getting started

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

`build_runner` regenerates the Drift, Freezed and JSON serialisation sources.
They are checked in, so the app runs without it unless you change a model or
table.

## Signed release builds

The release lifecycle scripts use Node.js built-ins; no `npm install` is needed.
First create local signing configuration files from the checked-in examples:

```sh
cp android/key.example.properties android/key.properties
cp ios/Flutter/Signing.xcconfig.example ios/Flutter/Signing.xcconfig
cp ios/ExportOptions.plist.example ios/ExportOptions.plist
cp macos/Runner/Configs/Signing.xcconfig.example macos/Runner/Configs/Signing.xcconfig
```

Fill in the Android passwords, key alias and keystore path in
`android/key.properties`. The sample `../upload-keystore.jks` path is resolved
relative to `android/app/`, so the keystore belongs at
`android/upload-keystore.jks`. Generate one from the `android/` directory if
needed; if you already have the intended signing identity, use its existing
keystore at this path instead of generating a replacement:

```sh
cd android
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

The `.jks` and `key.properties` are ignored by Git. Keep backups of the signing
keystore and passwords; they are needed for every future Android update. The
release Gradle tasks fail rather than silently signing with a debug key.

For Apple distribution targets, set your Apple Developer Team ID in the local
xcconfig files and Xcode export plist, then make sure the matching signing
certificates and provisioning profiles are installed in the local Xcode/keychain
environment. The checked-in local macOS configuration uses ad-hoc signing for
build verification; replace it with `Developer ID Application` or `Apple
Distribution` before submitting to the Mac App Store.
For macOS, choose `Developer ID Application` for direct distribution or
`Apple Distribution` for a Mac App Store build. These configs/certificates are
not committed.

```sh
npm run build:android  # signed APKs, one each for arm64-v8a and x86_64
npm run build:aab      # signed AAB containing both Android ABIs for Play
npm run build:ios      # unsigned arm64 iOS device .app for local verification
npm run build:app      # signed arm64 IPA exported for App Store Connect
npm run build:macos    # separate signed arm64 + x86_64 macOS .app bundles
```

Artifacts are archived under `dist/`. Android APKs are split per ABI and named
`Kritha-<version>-<abi>-RELEASE.apk`; the AAB
intentionally contains both ABIs so Google Play can generate device-specific
downloads. Apple App Store device apps use **arm64 only**—a simulator `x86_64`
slice must not be merged into an App Store IPA. `build:app` therefore creates
the store-ready arm64 IPA, while `build:ios` creates an unsigned arm64 device
`.app` for local verification. A valid Apple signing account and provisioning
profile are required for installation and distribution.

The copied Flexiyo lifecycle helpers are adapted here as
`scripts/build-release.js` and `scripts/bump.js`. `npm run bump:beta` or
`npm run bump:release` updates `pubspec.yaml` and `package.json`; commit those
changes, rerun the command to create a local version tag, and push the tag only
after reviewing it.

## Verification

```sh
dart format lib test
flutter analyze        # No issues found
flutter test           # 45 tests
flutter build apk --debug
flutter build ios --no-codesign
flutter build macos --release
flutter build windows --release   # from a Windows x64 host
```

`pubspec.yaml` pins `shared_preferences_foundation` 2.5.7 because its 2.6.0
Swift source uses trailing commas that Xcode 16.2's Swift 6.0.3 rejects. Remove
the override when the iOS toolchain is upgraded.

## What is implemented

### Design system

`lib/core/theme.dart` is the single source of truth, ported from the React
Native `src/theme/index.ts`:

- Colour palette (`KrithaColors`), typography (`KrithaText`), radii
  (`KrithaRadius`), spacing (`KrithaSpacing`), dimensions (`KrithaDimensions`)
  and motion (`KrithaMotion`)
- DM Sans (Google Fonts, 400/500/600/700) is bundled under `assets/fonts` and
  applied once through `ThemeData.fontFamily`; the theme's text styles also
  carry the default `textPrimary` colour. Normal component text leaves both
  properties out and inherits them, while secondary, muted, hint, disabled,
  destructive and monospace text keeps an explicit local colour/family
- Dark theme wiring for Material widgets, text selection and scrollbars

Feature code consumes these tokens instead of hardcoded values. The palette and
the single-source font/colour defaults are asserted in
`test/foundation_test.dart`. The written rules — including button anatomy,
press/focus feedback, menu geometry and composer patterns — are in
[`docs/DESIGN_CONVENTIONS.md`](docs/DESIGN_CONVENTIONS.md),
[`docs/BUTTONS.md`](docs/BUTTONS.md) and
[`docs/UI_PATTERNS.md`](docs/UI_PATTERNS.md).

### Responsive shell

Breakpoints live in `lib/core/responsive.dart` and depend only on the available
width — never on a device model or platform check:

| Viewport | Width | Sidebar | Composer |
| --- | --- | --- | --- |
| Compact | `< 600` | 78% overlay drawer, capped at 340 px | Capsule, expands on demand |
| Medium | `600 – < 840` | 78% overlay drawer, capped at 340 px | Capsule, expands on demand |
| Wide | `≥ 840` | Docked 300 px sidebar, collapsible | Expanded by default |

The message column is capped at 760 px and centred on wide screens. Assistant
replies have no avatar, name or bubble; user turns use a fully rounded bubble,
matching the original. The header floats over a blurred, darkened top band.
Each pill has no outer dead padding: its icon controls own the full 48px height,
so press and focus feedback fill the capsule instead of leaving a ring around a
smaller ink target. The compact header exposes
the sidebar menu, new chat and a per-chat ellipsis without repeating the app
branding; settings live in the sidebar footer. The ellipsis opens the shared
context menu with the chat title, Share, Pin/Unpin, Uploaded files, Find in
chat, Archive and Delete. While the IME is open, Android's back action dismisses
the keyboard first instead of closing the app; a second back then follows the
normal route behaviour.

### Adaptive composer

`lib/features/chat/widgets/composer/` contains:

- A compact capsule with attach, text field, mic and send controls
- The composer floats over the transcript instead of taking layout space. Its
  frosted `KrithaGlassSurface` blurs and dims the content behind it, with a soft
  fade above the capsule; the message list reserves the measured composer
  height so the last turn can still scroll clear
- Expansion on the second line of text, on any attachment, or by default on
  wide viewports. The layout switches immediately (no size animation) and the
  text field keeps focus and selection. A single line with an attachment stays
  at one line-height instead of leaving dead space above the bottom controls
- Image and document picking through `file_picker`, launched from the shared
  context menu (Camera, Plugins and Think harder are shown disabled), with a
  preview strip and per-attachment removal
- A 17px input size with a bounded internal scroll area so long drafts never
  overflow
- A persistent, closable “Editing this message will restart the conversation
  from here.” warning above the capsule while an earlier prompt is being
  edited. Sending deletes that turn and every later turn, then appends the
  replacement and a new reply; the X cancels the edit
- A dictation strip with a real microphone take: cancel (X), the Flexiyo
  waveform, stop-and-transcribe (square) and stop-transcribe-and-send (arrow).
  The waveform is ported from the Flexiyo recorder (newest bars on the right,
  3px bars with a 4px gap, 26px high, light-grey bars and a paused fade),
  wrapped in Kritha's own frosted composer chrome. The mic and primary blue
  action are separated by 8px. Stopping shows a “Transcribing…” state; no audio
  file is attached to the message. A local STT model is not bundled, so the
  transcribe step surfaces a clear missing-model error
- The Live Talk capsule, with listening / paused / speaking transitions,
  pause/resume and stop. Its centre pill is a fluid blue/cyan glow with a moving
  level wave, so the listening state reads as live audio rather than a static
  gradient; paused settles to a dim static state. It animates faithfully but
  does not pretend to transcribe: no STT/TTS model is bundled
- Assistant replies expose Copy, Read aloud, Share and More actions, each with a
  visible focus/press ink surface. Copy confirms inline; Share opens the native
  sheet through `share_plus`; Read aloud remains the TTS stub and More reports
  the unavailable response menu
- A scroll-to-bottom arrow appears when the transcript is more than 80px from
  the end, fades over 180ms, auto-hides after 1.5s and jumps to the bottom when
  pressed

### Shared context menu

`lib/widgets/context_menu.dart` is a reusable port of the React Native
`ContextMenu.tsx`: 200px wide, 48px middle rows, 24px corners, safe-area
clamping, 8px anchor gap, fade + scale from the nearest corner, destructive and
disabled states. The first and last rows are 56px: each owns an 8px outer edge
inset inside its press surface. There is no surface-level top/bottom gutter and
menus never draw separator lines, so feedback fills the menu without a visible
hairline or dead band. It is used by:

- the composer's attachment button
- the header's ellipsis (chat title, Share, Pin/Unpin, Uploaded files, Find in
  chat, Archive, Delete), right-aligned to the button
- long-pressing a user message (Copy, Edit message, with the message time as a
  header), right-aligned to the message column
- long-pressing a sidebar session (Pin/Unpin, Rename, Archive, Delete), opened
  at the press point and clamped inside the sidebar

Opening the menu never steals focus: the composer keyboard stays up. With the
keyboard visible the menu stays fully above the IME (Android draws the IME in a
separate window, so anything inside its rectangle would be hidden) and clamps to
the available space above it, ChatGPT-style. Rows are full-height press targets
with bold labels and 16px icons.

Sidebar rows are full 56px hit targets — including the six top actions, Pinned
and Recents — rather than text-height taps. The top actions are stacked with no
inter-item gap; their icons use Lucide's 600 weight at 24px, so they read as
boldly as the labels. The drawer no longer has a close icon; the backdrop and
edge swipe close it.

Attachment metadata (name, path, size, kind, MIME type) is persisted as JSON on
the message row (Drift schema v3), so previews and sent messages survive
restarts.

### Sessions

Sessions are first-class SQLite rows, not temporary UI state:

- **Create** — “New chat” opens a draft. The first prompt creates the session
  and titles it from that prompt (long prompts are trimmed with an ellipsis).
- **Switch** — tapping a Pinned or Recents row loads that session's messages
  and closes the overlay drawer.
- **Pin / unpin** — persisted and reflected by moving the row between the
  Pinned and Recents sections.
- **Rename** — persisted from the long-press menu.
- **Archive** — removes the chat from the active list; “Archived Chats” lists
  archived sessions with restore and delete.
- **Delete** — deletes the session and its messages in one transaction; if it
  was open, the newest remaining session is selected.
- **Reset** — settings clears every session/message and re-seeds the fixture.

Schema v3 adds `chat_sessions` and `chat_entries.sessionId`. Messages written by
schema v1/v2 are adopted into an “Earlier conversation” session on first open,
so upgrades do not lose history.

### Persistence and settings

- Drift/SQLite stores sessions and messages; sessions have pin/archive flags
  and timestamps, and the fixture is seeded once
- `attachmentsJson` is decoded through `ChatAttachment.fromJson`
- The settings screen reports runtime probes (sherpa-onnx, ONNX Runtime,
  SQLite, secure storage, microphone, recorder, audio player, API base URL) and
  can reset local history. Runtime information lives here, not in the chat
  header.

The design rules and interaction patterns live alongside the component
inventory:

- [`docs/DESIGN_CONVENTIONS.md`](docs/DESIGN_CONVENTIONS.md) — tokens,
  typography, colour, spacing, responsive rules and the change checklist
- [`docs/BUTTONS.md`](docs/BUTTONS.md) — every button/row/menu control, sizing,
  states and press/focus feedback
- [`docs/UI_PATTERNS.md`](docs/UI_PATTERNS.md) — shell, header, sidebar,
  composer, dictation, Live Talk and overlay patterns
- [`docs/COMPONENTS.md`](docs/COMPONENTS.md) — component inventory and every
  remaining stub with hand-off notes

## Project layout

```
assets/
  fonts/                       Bundled DM Sans 400/500/600/700
  images/kritha_logo.png
lib/
  app.dart                     MaterialApp / theme / router wiring
  core/
    responsive.dart            Breakpoints and viewport helpers
    theme.dart                 Design tokens, DM Sans and ThemeData
    providers.dart             Riverpod providers (database, runtime)
    router.dart                go_router routes
  data/
    app_database.dart          Drift tables, session/message queries, v3 migration
    seed_messages.dart         Fixture conversation and canned replies
  features/
    chat/
      chat_controller.dart     Sessions, per-session history, send, CRUD
      chat_screen.dart         Adaptive shell, floating frosted composer,
                               scroll-to-bottom arrow, keyboard back guard
      dictation_controller.dart  Microphone capture, amplitude levels, STT seam
      widgets/                 Header, sidebar, message list, Markdown,
                               attachments, response actions, composer/
    settings/                  Runtime probes and history controls
  models/                      Message, attachment and session models
  services/runtime_probe.dart  Startup probes for native packages
  widgets/                     Shared context menu and frosted glass surface
docs/DESIGN_CONVENTIONS.md     Token, typography and visual rules
docs/BUTTONS.md                Button and interaction spec
docs/UI_PATTERNS.md            Shell, header, composer, overlay and Live Talk patterns
docs/COMPONENTS.md             Component inventory and stub hand-off list
```

## Known gaps versus the React Native app

These are deliberate scope boundaries for this foundation, not hidden stubs:

- **Live Talk transcription/synthesis** — the capsule and its state machine are
  present, but no speech-to-text or text-to-speech model is bundled. Video and
  screen sharing are visible stubs.
- **Dictation transcription** — the microphone capture, waveform, cancel,
  stop-and-transcribe and stop-transcribe-and-send controls are real and match
  the RN flow. The finished `.m4a` is deleted rather than attached; it is not
  transcribed into the text field because no STT model is bundled, so the
  transcribe step reports the missing model.
- **Camera capture and read-aloud** — the context menu exposes Camera, Photos,
  Files, Plugins and Think harder to match the reference; only Photos and Files
  are enabled. Camera, Plugins and Think harder are disabled rather than shown
  as dead actions. Read-aloud is a visible TTS stub.
- **Real assistant engine** — replies come from `demoReplyFor`; there is no
  backend or local LLM. LiteRT-LM is not in the dependency set.
- **Attachment file lifecycle** — picker paths are stored but not copied into
  app documents yet, so a picker cache cleanup can invalidate an old preview.
- **Message editing** — editing restarts the conversation from that turn by
  deleting the edited turn and everything after it. It does not create a branch
  or preserve attachments from the original turn.
- **Sidebar utilities** — Library, Extensions, Permissions, More and
  chat search are visible stubs.
- **Settings depth** — runtime probes and reset are real; the remaining RN
  settings toggles are not implemented.
