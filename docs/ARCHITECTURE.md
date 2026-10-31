# Architecture and implementation

This document describes how Kritha is built: the shell, the conversation
pipeline, persistence, the model and provider workspaces, and the boundaries of
the current implementation. Product-level setup lives in the
[README](../README.md).

## Contents

- [Application layers](#application-layers)
- [Design system](#design-system)
- [Responsive shell](#responsive-shell)
- [Adaptive composer](#adaptive-composer)
- [Shared context menu](#shared-context-menu)
- [Sessions](#sessions)
- [Persistence and settings](#persistence-and-settings)
- [Intelligence](#intelligence)
- [Models workspace](#models-workspace)
- [Providers workspace](#providers-workspace)
- [Project layout](#project-layout)
- [Known gaps](#known-gaps)

## Application layers

Kritha is a Flutter application with four cooperating layers:

| Layer | Responsibility |
| --- | --- |
| Presentation | Responsive shell, chat transcript, composer, model and provider workspaces, settings |
| State | Riverpod controllers for chat, catalogue, setup, providers and model configuration |
| Domain | Inference contracts, request routing, conversation mapping, artifact and provider rules |
| Platform | Drift/SQLite, secure storage, SharedPreferences, native LiteRT-LM and sherpa ONNX runtimes |

State never reaches into widgets and widgets never open databases or keychains
directly. Native runtimes sit behind typed adapters, so a missing runtime is
reported as an unavailable capability instead of a crash.

## Design system

`lib/core/theme.dart` is the single source of truth for the visual language:

- Colour palette (`KrithaColors`), typography (`KrithaText`), radii
  (`KrithaRadius`), spacing (`KrithaSpacing`), dimensions (`KrithaDimensions`)
  and motion (`KrithaMotion`).
- DM Sans (Google Fonts, 400/500/600/700) is bundled under `assets/fonts` and
  applied once through `ThemeData.fontFamily`. Theme text styles also carry the
  default `textPrimary` colour, so normal component text inherits both while
  secondary, muted, hint, disabled, destructive and monospace text keeps an
  explicit local colour or family.
- Shared input styling (`KrithaInputs`) gives popup, dialog and settings fields a
  visible `borderSubtle` outline and a `borderAccent` focus outline.
- Dark-theme wiring covers Material widgets, text selection and scrollbars.

Feature code consumes these tokens instead of hardcoded values. The palette,
font defaults and input borders are asserted in
`test/app/app_shell_test.dart`. Written rules live in
[`DESIGN_CONVENTIONS.md`](DESIGN_CONVENTIONS.md), [`BUTTONS.md`](BUTTONS.md) and
[`UI_PATTERNS.md`](UI_PATTERNS.md).

## Responsive shell

Breakpoints live in `lib/core/responsive.dart` and depend only on available
width, never on a device model or platform check:

| Viewport | Width | Sidebar | Composer |
| --- | --- | --- | --- |
| Compact | `< 600` | 78% overlay drawer, capped at 340 px | Capsule, expands on demand |
| Medium | `600 – < 840` | 78% overlay drawer, capped at 340 px | Capsule, expands on demand |
| Wide | `≥ 840` | Docked 300 px sidebar, collapsible | Expanded by default |

The message column is capped at 760 px and centred on wide screens. Assistant
replies have no avatar, name or bubble; user turns use a fully rounded bubble.
The header floats over a blurred, darkened top band. Each header pill has no
outer dead padding: its icon controls own the full 48 px height, so press and
focus feedback fill the capsule. The compact header exposes the sidebar menu,
new chat and a per-chat ellipsis without repeating the app branding; settings
live in the sidebar footer. The ellipsis opens the shared context menu with the
chat title, Share, Pin/Unpin, Uploaded files, Find in chat, Archive and Delete.
While the IME is open, Android's back action dismisses the keyboard first
instead of closing the app; a second back then follows normal route behaviour.

## Adaptive composer

`lib/features/chat/widgets/composer/` contains the composer stack:

- A compact capsule with attach, text field, mic and send controls.
- The composer floats over the transcript instead of taking layout space. Its
  frosted `KrithaGlassSurface` blurs and dims the content behind it, with a soft
  fade above the capsule; the message list reserves the measured composer
  height so the last turn can still scroll clear.
- Expansion on the second line of text, on any attachment, or by default on
  wide viewports. The layout switches immediately (no size animation) and the
  text field keeps focus and selection. A single line with an attachment stays
  at one line-height instead of leaving dead space above the bottom controls.
- Image and document picking through `file_picker`, launched from the shared
  context menu (Camera, Plugins and Think harder are shown disabled), with a
  preview strip and per-attachment removal.
- A 17 px input size with a bounded internal scroll area so long drafts never
  overflow.
- A persistent, closable “Editing this message will restart the conversation
  from here.” warning above the capsule while an earlier prompt is being
  edited. Sending deletes that turn and every later turn, then appends the
  replacement and a new reply; the X cancels the edit.
- A dictation strip with a real microphone take: cancel (X), the Flexiyo-style
  waveform, stop-and-transcribe (square) and stop-transcribe-and-send (arrow).
  The waveform uses newest bars on the right, 3 px bars with a 4 px gap, 26 px
  height, light-grey bars and a paused fade, wrapped in Kritha's own frosted
  composer chrome. The mic and primary blue action are separated by 8 px.
  Stopping shows a “Transcribing…” state; no audio file is attached to the
  message because no local STT model is bundled, so the transcribe step
  surfaces a clear missing-model error.
- The Live Talk capsule, with listening / paused / speaking transitions,
  pause/resume and stop. Its centre pill is a fluid blue/cyan glow with a moving
  level wave, so the listening state reads as live audio rather than a static
  gradient; paused settles to a dim static state. It animates faithfully but
  does not pretend to transcribe: no STT/TTS model is bundled.
- Assistant replies expose Copy, Read aloud, Share and More actions, each with a
  visible focus/press ink surface. Copy confirms inline; Share opens the native
  sheet through `share_plus`; Read aloud remains the TTS stub and More reports
  the unavailable response menu.
- A scroll-to-bottom arrow appears when the transcript is more than 80 px from
  the end, fades over 180 ms, auto-hides after 1.5 s and jumps to the bottom
  when pressed.

## Shared context menu

`lib/widgets/context_menu.dart` provides one reusable menu: 200 px wide, 48 px
middle rows, 24 px corners, safe-area clamping, 8 px anchor gap, fade + scale
from the nearest corner, destructive and disabled states. The first and last
rows are 56 px: each owns an 8 px outer edge inset inside its press surface.
There is no surface-level top/bottom gutter and menus never draw separator
lines, so feedback fills the menu without a visible hairline or dead band.

It is used by:

- the composer's attachment button;
- the header's ellipsis (chat title, Share, Pin/Unpin, Uploaded files, Find in
  chat, Archive, Delete), right-aligned to the button;
- long-pressing a user message (Copy, Edit message, with the message time as a
  header), right-aligned to the message column;
- long-pressing a sidebar session (Pin/Unpin, Rename, Archive, Delete), opened
  at the press point and clamped inside the sidebar.

Opening the menu never steals focus: the composer keyboard stays up. With the
keyboard visible the menu stays fully above the IME (Android draws the IME in a
separate window, so anything inside its rectangle would be hidden) and clamps to
the available space above it. Rows are full-height press targets with bold
labels and 16 px icons.

Sidebar rows are full 56 px hit targets — including the six top actions, Pinned
and Recents — rather than text-height taps. The top actions are stacked with no
inter-item gap; their icons use a heavy 600-weight stroke at 24 px, so they read
as boldly as the labels. The drawer has no close icon; the backdrop and edge
swipe close it.

Attachment metadata (name, path, size, kind, MIME type) is persisted as JSON on
the message row (Drift schema v3), so previews and sent messages survive
restarts.

## Sessions

Sessions are first-class SQLite rows, not temporary UI state:

- **Create** — “New chat” opens a draft. The first prompt creates the session
  and titles it from that prompt (long prompts are trimmed with an ellipsis).
- **Switch** — tapping a Pinned or Recents row loads that session's messages
  and closes the overlay drawer.
- **Pin / unpin** — persisted and reflected by moving the row between the
  Pinned and Recents sections.
- **Rename** — persisted from the long-press menu.
- **Archive** — removes the chat from the active list; Archived chats under
  Settings → Privacy lists archived sessions with restore and delete.
- **Delete** — deletes the session and its messages in one transaction; if it
  was open, the newest remaining session is selected.
- **Clear history** — settings clears every session and message after
  confirmation. Fresh installs start with an empty history; no demo fixture is
  seeded.

Schema v3 adds `chat_sessions` and `chat_entries.sessionId`. Messages written by
schema v1/v2 are adopted into an “Earlier conversation” session on first open,
so upgrades do not lose history. Schema v4 adds configuration and artifact rows
for the Model Setup Wizard.

## Persistence and settings

- Drift/SQLite stores sessions and messages; sessions have pin/archive flags
  and timestamps. New installs start empty, and clearing history does not
  recreate a fixture.
- `attachmentsJson` is decoded through `ChatAttachment.fromJson`.
- The settings screen reports runtime probes (sherpa-onnx, ONNX Runtime,
  SQLite, secure storage, microphone, recorder, audio player, API base URL) and
  can clear local history after confirmation. Runtime information lives here,
  not in the chat header.
- Secrets use the shared `SecureStorageService`. Hub tokens and inference
  provider credentials have separate keys and validation rules.

## Intelligence

`lib/features/intelligence/` defines the inference request/response contracts,
a minimal request router, the application-facing engine, a LiteRT-LM adapter
and the persisted model selection:

- Settings stores a validated `.litertlm` path (present, regular file,
  non-empty) and reports the file separately from the loaded engine. Selecting
  a file does not load weights. On mobile, the platform picker may hand back a
  cached copy; the saved path is revalidated before every request.
- `ChatController.send` delegates persisted-history mapping to
  `ConversationContextBuilder`, streams the reply through the engine and only
  saves the assistant turn after a successful completion. Cancelling stops
  native generation and discards the partial text; retrying regenerates for the
  existing user turn without saving it again.
- Model loading happens on the first request. Settings combines file validation
  with an explicit engine lifecycle (file ready, loading, loaded, failed,
  released) and never initializes the runtime just to render diagnostics.
- Attachments are persisted but not sent to the model; a text prompt is
  required. LiteRT-LM conversations are created per request because reuse across
  turns has no verified reset/cancel lifecycle.

## Models workspace

`lib/features/models/` provides a Hub-backed discovery workspace and a separate
Active Models surface:

- Explore searches `https://huggingface.co/api/models` with capability filters,
  sort order, an editable list of Hub filters and `Link`-header cursor
  pagination. The default `filter=litert-lm` tag keeps the catalogue focused
  on runnable LiteRT-LM repositories. The filter popup shows filter values only
  (for example `litert-lm`), keeps presets as togglable, non-deletable chips,
  and lets users add or remove their own keywords. Public browsing works
  without a token. Cards resolve the real publisher avatar with one cached
  `/api/{organizations|users}/<name>/avatar` lookup per publisher; rendered
  initials are only a fallback. The first page loads as a left-to-right shimmer
  skeleton of eight cards rather than a centred spinner.
- Model details load the full repository record, file tree and `README.md`.
  The header offers Open in HF Hub and Copy repository URL. Inline loading uses
  a section-shaped skeleton for overview, setup, card and files. The Model Card
  title carries copy and option actions; the option menu downloads the Markdown
  file or opens its raw Hub URL.
- The overview header shows the publisher logo and `namespace/model-name` with
  a copy action, followed by followers, likes and downloads in that order.
  Metadata is grouped into Tasks, Libraries, Languages, Licenses and Other;
  pills render the exact Hub tag values as received, while a normalized copy
  (case and separators ignored, so `LiteRT-LM` matches `litertlm`) is used only
  for internal format and library matching. Languages collapse to a
  single “N languages” pill that expands on tap.
- Model Setup lists only published technical facts (architecture, parameters,
  weights, quantization, format, library, task, context window). Its primary
  action opens the Model Setup Wizard. Pre-checks reuse the runtime probe and
  the loaded Hub details to map configuration, helper and weight artifacts,
  assess supported formats and preserve device, runtime, artifact and
  compatibility results for the later artifact and testing steps. They never
  download, load or run model weights.
- Release builds keep `org.rockstudio.litertlm.**` and
  `com.google.ai.edge.litertlm.**` via `android/app/proguard-rules.pro`. R8
  cannot see the JNI class lookups, so without the rules it strips
  `LiteRtLmJniBridge` and the runtime probe reports LiteRT-LM as unavailable.
- Step 2 manages artifact selection per configuration in a table-first layout:
  Config Files, Helper Files and Model Weights are expandable sections with
  selection-aware round checkboxes (`all`/`partial`/`none`), row checkboxes,
  and unlabelled rows whose controls explain themselves: target path and source
  split the remaining width equally, then download/delete, choose/replace and
  the row menu sit in one intrinsic cluster with even gaps. Phones use the same
  unlabelled stack, wrapping the action cluster only when the row is too narrow.
  Selection and download state are separate; unselected rows keep their
  metadata and context menu but disable editing and normal actions. Download,
  Replace, Delete/Choose, Add Row, tri-state section toggles and the three-item
  row menu are real. Weight setup selects at most one file, preferring an
  identifiable primary weight, then `fp4`/`int4`, then the smallest sized
  weight. Every configuration owns its own
  `model_artifacts/<repository>/<configuration>` root; rows store target paths
  relative to it, repository downloads land there and device files are copied
  in. `Download All` and row actions use the real Hugging Face resolve endpoint
  and report byte progress. Paused downloads keep their partial file and resume
  with a `Range` request. Only configurations and their artifact rows are
  persisted, so a future Configured Models screen can list them; pre-check
  results stay in memory and are re-evaluated on every open. `Test` requires
  every selected artifact to be downloaded, while `Save` only requires selected
  rows to have a source and a valid target path.
- Model Card renders the README Markdown with View more/View less and an
  explicit empty state. Model Files shows the branch and a clickable latest
  commit, then directories and files with sizes; only the first six entries are
  visible until View more, and links open the Hub externally. A Hub entry is
  never described as downloaded, verified or runnable.
- A dedicated Dio client sends an optional Hugging Face token as a Bearer
  header. It has no request logging, and the token is stored in platform secure
  storage, never shown after saving, and can be replaced or removed.
- Active Models persists capability assignments in SharedPreferences. Local
  inventory and connected provider models can be assigned per capability; only
  the validated local LiteRT-LM text path has an execution path in this build,
  so provider-hosted routing and non-text execution are not claimed.
- Custom catalogue is a gated Pro explanation screen only. It does not configure
  or contact an endpoint.

## Providers workspace

`lib/features/providers/` configures inference connections independently of the
Hub catalogue:

- Entries cover the local LiteRT-LM runtime plus OpenAI, Anthropic, Google
  Gemini, xAI, Groq, DeepSeek, Perplexity, Qwen, Hugging Face, Mistral and
  user-created OpenAI-compatible endpoints. All but Anthropic use a shared
  OpenAI-compatible adapter; Anthropic keeps its Messages API adapter.
- The first settings load renders provider-shaped skeletons; only screen-level
  content is skeletonized, never individual buttons or labels.
- Every provider card keeps one action row at natural width: Test and Usage on
  the left, Connect or Configure on the right. Test and Usage stay visible but
  disabled until the provider has its required credentials. Connect is a filled
  primary action; Configure uses the neutral outlined treatment of Test/Usage.
- Credentials live in secure storage under provider-specific keys; the Hub token
  is a separate secret. Saved keys are never rendered back into the UI.
- Connection tests perform real HTTP requests to each provider's models
  endpoint and report the actual status. They do not route chat through the
  provider or claim inference success.
- Usage is a local request counter per provider stored in SharedPreferences.
  The popup reports only recorded counts; it never estimates spend or claims
  remote billing figures.

## Project layout

```text
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
    network/                   Shared Dio transport classification
    storage/                   Shared platform secure-storage service
  data/
    app_database.dart          Drift tables, session/message queries, migrations
  features/
    chat/
      chat_controller.dart     Sessions, history, streaming send, cancel, retry
      chat_screen.dart         Adaptive shell, floating frosted composer,
                               scroll-to-bottom arrow, keyboard back guard
      dictation_controller.dart  Microphone capture, amplitude levels, STT seam
      widgets/                 Header, sidebar, message list, Markdown,
                               attachments, response actions, composer/
    models/                    Hub catalogue, filters, token, details,
                               Active Models, Model Setup Wizard
    providers/                 Inference connections, credentials, tests
    settings/                  Runtime probes, model selection and history controls
    intelligence/              Inference contracts, router, engine, LiteRT-LM
                               adapter and model configuration
  models/                      Message, attachment and session models
  services/runtime_probe.dart  Startup probes for native packages
  widgets/                     Shared context menu, glass surfaces and skeletons
docs/                          Design, component and architecture documentation
test/                          Unit, widget and integration tests by feature
```

## Known gaps

These are deliberate scope boundaries, not hidden stubs:

- **Live Talk transcription/synthesis** — the capsule and its state machine are
  present, but no speech-to-text or text-to-speech model is bundled. Video and
  screen sharing are visible stubs.
- **Dictation transcription** — microphone capture, waveform, cancel,
  stop-and-transcribe and stop-transcribe-and-send controls are real. The
  finished `.m4a` is deleted rather than attached because no STT model is
  bundled, so the transcribe step reports the missing model.
- **Camera capture and read-aloud** — the context menu exposes Camera, Photos,
  Files, Plugins and Think harder; only Photos and Files are enabled. Camera,
  Plugins and Think harder are disabled rather than shown as dead actions.
  Read-aloud is a visible TTS stub.
- **Real assistant engine** — the chat flow is wired to the intelligence layer
  and a persisted `.litertlm` path, but no model ships with the app and no real
  generation has been verified in this workspace. Text-only prompts are
  supported; attachment contents are not sent to the model.
- **Conversation reuse** — each request creates a fresh LiteRT-LM conversation
  and replays the persisted history. Reusing one native conversation per chat is
  deferred until reset/cancel lifecycle behaviour is verified on a device.
- **Attachment file lifecycle** — picker paths are stored but not copied into
  app documents yet, so a picker cache cleanup can invalidate an old preview.
- **Message editing** — editing restarts the conversation from that turn by
  deleting the edited turn and everything after it. It does not create a branch
  or preserve attachments from the original turn.
- **Sidebar utilities** — Library, Plugins, More and chat search are visible
  stubs. Archived chats and Permissions live under Settings → Privacy.
- **Settings depth** — runtime probes, local model selection/removal and
  confirmed history clearing are real; the remaining settings toggles are not
  implemented.
- **Hub model download and activation** — Explore, search, filters, details,
  files and model cards use the real Hub API. A Hub repository is never treated
  as downloaded or runtime-compatible; only an already validated local
  `.litertlm` file can be assigned to the text capability.
- **Hosted provider routing** — providers can be connected, configured and
  tested with real HTTP requests, but chat still uses the local intelligence
  engine.
- **Active model routing** — capability assignments are persisted and shown with
  honest status, but the single local text model is still selected in Settings.
  Multi-model routing and non-text execution paths are not implemented.
- **Custom catalogue** — the entry is a gated Pro explanation screen; endpoint
  configuration, response schemas and billing are not implemented.
