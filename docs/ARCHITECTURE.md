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
for the Model Setup Wizard; schema v5 adds `action_preferences`, a row-per-action
store for choices such as muted confirmation prompts.

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

`lib/features/intelligence/` owns canonical task metadata, typed request
contracts, provider/runtime selection and lifecycle management. The main
composition is `IntelligenceEngine` -> `RequestRouter` -> an
`InferenceProvider`; the router never retries or silently selects another
model.

### Tasks and metadata

`models/task_registry.dart` is the canonical task registry. `AiTaskId` exposes
stable string identifiers such as `text_generation`, `image_text_to_text`,
`automatic_speech_recognition` and `embeddings`. A task definition keeps its
display name, description, input/output modalities and whether Kritha currently
has an executable pipeline. Tasks, modalities and features are separate:
features include reasoning, tool calling and structured output, while
modalities include text, image, audio and video.

The registry distinguishes a recognised task from an architecture-supported
task and from an executable task. Text generation is currently the only
executable task. Other registered tasks can be identified and validated, but
return `UnsupportedTaskException` before inference when no request pipeline
exists.

`TaskDeclaration` records metadata confidence (`explicit`, `partial` or
`unknown`), source (`provider`, `huggingFace` or `manual`), upstream values and
refresh time. Missing provider metadata remains unknown; it is never promoted
to text support. `CatalogueModel` maps Hugging Face pipeline tags through this
registry and preserves the original upstream tag.

### Requests, validation and routing

`AiRequest` retains the existing text-chat message contract and can carry typed
`AiInput` values: `AiTextInput`, `AiImageInput`, `AiAudioInput` and
`AiVideoInput` (bytes or a reference). Binary content is not placed in string
metadata. `AiRequestValidator` checks message order, sampler bounds, requested
task, required modalities and binary input validity. The current text pipeline
rejects binary media, while recognised non-text tasks fail explicitly because
their execution pipelines are not implemented.

`RequestRouter` resolves the canonical task's Active Models target, provider
and exact model identity, then verifies declared capabilities. When Active
Models has task assignments, an unassigned task is unavailable rather than
falling through to another model. `AiResponse` streams cumulative text
snapshots; normal stream completion, cancellation and stream errors remain
distinct. Providers release resources on completion, cancellation, failure or
disposal.

### Persistence and chat lifecycle

Settings persists and revalidates a non-empty `.litertlm` path before execution.
`ChatController` maps stored history into a request, starts loading lazily on
the first request, saves the assistant turn only after successful completion,
and discards partial output on cancellation. LiteRT-LM conversations are
created per request because reuse has no verified reset/cancel lifecycle.

## Models workspace

`lib/features/models/` provides a three-destination workspace. Active Models and
Provider Models share a management scaffold; Explore opens the Hub-backed
discovery surface:

- On compact and medium screens Active Models and Provider Models use a tappable
  title menu to switch destinations and keep a right-aligned Explore Models
  action in the header. Back pops the route. Wide screens nest both destinations
  under Models in the expandable docked sidebar and omit the back control.
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
  selection-aware round checkboxes (`all`/`partial`/`none`), row checkboxes and
  a collapse toggle, with no column header. Wide rows put the source on the left
  and the target path on the right, each taking half the remaining width,
  followed by an intrinsic action cluster: download/delete, insert-row,
  replace/choose and a red remove-row icon at uniform gaps. Phones stack source
  over target and keep the same actions beside the path they act on:
  replace/choose and remove-row beside the source, download/delete and
  insert-row beside the target. Text buttons share one label slot and icon
  buttons share one size, so rows stay aligned; long names use middle
  truncation with a 14-character tail and reveal the full value on hover.
  Selection and download state are separate; unselected rows keep their
  metadata but disable editing and actions. The list header shows
  `N of M selected` on the left and the bulk action on the right: `Download
  All`, which flips to a destructive `Delete All` once every selected row is
  downloaded. Deleting a copy, removing a selected row, replacing a source and
  deleting every copy all confirm first, and each prompt carries a
  `Don't ask again` tick persisted per action in `action_preferences`.
  Duplicate normalized target paths flag both target boxes. Weight setup
  selects at most one file, preferring an identifiable primary weight, then
  `fp4`/`int4`, then the smallest sized weight. Every configuration owns its
  own `model_artifacts/<repository>/<configuration>` root; rows store target
  paths relative to it, repository downloads land there and device files are
  copied in. Row actions and `Download All` use the real Hugging Face resolve
  endpoint and report byte progress. Paused downloads keep their partial file
  and resume with a `Range` request. Only configurations, their artifact rows
  and action preferences are persisted, so a future Configured Models screen
  can list them; pre-check results stay in memory and are re-evaluated on every
  open. `Test` requires every selected artifact to be downloaded, while `Save`
  only requires selected rows to have a source and a valid target path.
- Model Card renders the README Markdown with View more/View less and an
  explicit empty state. Model Files shows the branch and a clickable latest
  commit, then directories and files with sizes; only the first six entries are
  visible until View more, and links open the Hub externally. A Hub entry is
  never described as downloaded, verified or runnable.
- A dedicated Dio client sends an optional Hugging Face token as a Bearer
  header. It has no request logging, and the token is stored in platform secure
  storage, never shown after saving, and can be replaced or removed.
- Active Models persists versioned canonical task assignments in
  SharedPreferences. Legacy capability-keyed records are read and migrated; a
  legacy mirror remains for older installations. Assignments retain
  provider-aware model identity, a single task or an individually enabled
  multimodal task set. Multimodal assignments take priority for enabled tasks,
  while invalid or stale records remain diagnosable instead of being silently
  discarded. The existing UI still presents capability-oriented slots while
  the backend stores canonical task IDs.
- Provider Models lists normalized discovery records grouped by configured
  provider. It does not cache or invent model capabilities.
- Custom catalogue is a gated Pro explanation screen only. It does not configure
  or contact an endpoint.

## Providers workspace

`lib/features/providers/` configures inference connections independently of the
Hub catalogue:

- Entries cover the local LiteRT-LM runtime plus Anthropic, Google Gemini, xAI,
  DeepSeek, Qwen/DashScope, Hugging Face, Mistral and user-created
  OpenAI-compatible endpoints. OpenAI, Groq and Perplexity are not default
  built-ins. Legacy saved records for those IDs can still be restored through
  legacy definitions without appearing in the default provider list.
- Discovery is independent from inference. Anthropic uses native `GET /v1/models`
  with `x-api-key` and `anthropic-version` headers and follows `has_more` /
  `after_id`. Gemini uses native `GET
  https://generativelanguage.googleapis.com/v1beta/models` with an API-key
  query parameter and `nextPageToken`. xAI queries separate native language,
  image-generation and video-generation catalogues. DeepSeek uses
  `https://api.deepseek.com/models`, independent of the `/v1` inference base
  URL. Qwen uses the configured DashScope regional host and paged native
  `/api/v1/models`. Hugging Face uses
  `https://router.huggingface.co/v1/models` for chat models while the Hub
  catalogue remains the broader task source. Mistral uses its native `/v1/models`
  listing with bearer authentication.
- Discovery normalizes model identity, display name, task declarations,
  modalities, features, context/output limits, raw provider metadata,
  provenance and confidence. Missing declarations remain unknown; partial and
  explicit unsupported task fields are preserved. Native provider metadata is
  not replaced by a generic `/models` assumption. The custom OpenAI-compatible
  provider supports the generic models/chat shape only and does not gain native
  provider metadata or unsupported task pipelines.
- The first settings load renders provider-shaped skeletons; only screen-level
  content is skeletonized, never individual buttons or labels.
- Every provider card keeps one action row at natural width: Test and Usage on
  the left, Connect or Configure on the right. Test and Usage stay visible but
  disabled until the provider has its required credentials. Connect is a filled
  primary action; Configure uses the neutral outlined treatment of Test/Usage.
- Credentials live in secure storage under provider-specific keys; the Hub token
  is a separate secret. Saved keys are never rendered back into the UI.
- Connection tests and discovery perform real HTTP requests and report actual
  status/model metadata. They do not route chat through the provider or claim
  unsupported inference success.
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
                               Active/Provider/Explore Models, Model Setup Wizard
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
- **Real assistant engine** — the chat flow is wired to the unified local
  provider and registered LiteRT-LM runtime, but no model ships with the app
  and no production-weight generation has been verified in this workspace.
  Text generation is executable; registered non-text tasks return an explicit
  unsupported-task result.
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
  `.litertlm` artifact can be selected for the local text runtime.
- **Hosted provider execution** — retained providers have normalized discovery
  and existing inference adapters, but remote execution still depends on a
  configured adapter/model route and does not make unsupported tasks runnable.
- **Multimodal execution** — typed image/audio/video inputs, task metadata and
  validation are implemented, but no corresponding production request pipeline
  is implemented yet.
- **Custom catalogue** — the entry is a gated Pro explanation screen; endpoint
  configuration, response schemas and billing are not implemented.
