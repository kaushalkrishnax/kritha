# Component & Stub Map

This is the working inventory for the Flutter port. It lists every component,
what is real today, and the exact functions still left as stubs so the next
cloning task can be scoped by file or feature name.

Before adding or changing a component, follow
[`DESIGN_CONVENTIONS.md`](DESIGN_CONVENTIONS.md),
[`BUTTONS.md`](BUTTONS.md) and [`UI_PATTERNS.md`](UI_PATTERNS.md). This file is
the inventory; those files are the rules.

Status legend:

- **Real** — backed by SQLite, the filesystem, the microphone, or a real package.
- **Visual** — the interaction/state machine is complete, but the native runtime
  is intentionally absent.
- **Stub** — the UI affordance exists and reports clearly that it is unavailable.
- **Gap** — no affordance yet; listed at the end as future work.

## Data flow

```
ChatScreen
  └─ chatControllerProvider (AsyncNotifier<ChatState>)
       ├─ AppDatabase (Drift / SQLite, schema v3)
       │    ├─ chat_sessions: id, title, timestamps, pinned, archived
       │    └─ chat_entries: id, sessionId, role, content, createdAt,
       │                      attachmentsJson
       └─ ChatState: sessions, archivedSessions, currentSessionId,
                     messages, sending

ChatComposer
  ├─ composerProvider (draft, attachments, expansion, Live Talk phase)
  │    └─ LiveTalkBar → live_talk_pill.dart (synthetic listening glow)
  └─ dictationProvider (microphone phase, elapsed time, amplitude levels)
       └─ DictationBar → recording_waveform.dart → transcribe seam
            (no audio attachment; the temp file is deleted)

Intelligence (wired to chat; no model bundled)
  intelligenceEngineProvider → RequestRouter → LiteRtLmProvider
    └─ NativeLiteRtLmEngine → litertlm Engine/Conversation
         (configuredModelProvider comes from the validated Settings selection;
          nothing loads until the first request)

Models (Hub discovery, no runtime claim)
  ModelsScreen → catalogueProvider → ModelCatalogue → HuggingFaceHubClient
    ├─ featuredCatalogueProvider (popular / recommended)
    ├─ modelDetailsProvider (record, file tree, README)
    └─ huggingFaceTokenProvider → SecureStorageService
         (Bearer only to the Hub; separate Hugging Face key)

Active Models
  activeModelsProvider → ActiveModelStore (SharedPreferences)
    └─ status is derived from local inventory and connected providers

Providers (configuration, not routing)
  providersControllerProvider → ProviderSettingsStore (SharedPreferences)
    ├─ ProviderCredentialStore → SecureStorageService (per-provider keys)
    └─ ProviderConnectionTester → real models-endpoint HTTP request
```

Session operations are written immediately; messages are loaded per session.
A new chat is a draft (`currentSessionId == null`) until the first prompt, at
which point the session row is created with a title derived from that prompt.

---

## Screens and shell

| Component | File | Status | Notes / stub work |
| --- | --- | --- | --- |
| `KrithaApp` | `lib/app.dart` | Real | Theme, router wiring. |
| `ChatScreen` | `lib/features/chat/chat_screen.dart` | Real | Responsive shell, drawer/docked sidebar, session-change scroll, empty-chat state, loading/error screens, floating frosted composer and scroll-to-bottom arrow. `_KeyboardBackGuard` dismisses the IME before allowing a route pop. |
| `ChatHeader` | `lib/features/chat/widgets/chat_header.dart` | Real | Floating pills over the blurred top band: sidebar/menu, New chat and a per-chat ellipsis, with equal pill padding and full icon ripples. The ellipsis opens the shared menu with the chat title, Share, Pin/Unpin, Uploaded files, Find in chat, Archive and Delete. Settings stay in the sidebar footer; **wake-word runtime is a stub**. |
| `ChatSidebar` | `lib/features/chat/widgets/chat_sidebar.dart` | Real | SQLite sessions, Pinned/Recents, six contiguous 56 px top action rows in the order New chat, Library, Models, Providers, Plugins, More (no inter-item gap), 24 px Lucide 600-weight action icons, 56 px session rows, long-press menu, rename dialog, archive list, settings/account strip. `Models` and `Providers` open their workspaces; the compact rail repeats the same order as icon buttons. |
| `ArchivedSessionsDialog` | same file | Real | Lists archived sessions; restore and delete are persisted. Also opened from Settings → Privacy. |
| `SettingsScreen` | `lib/features/settings/settings_screen.dart` | Real | Runtime probes, local model selection/removal and confirmed history clearing are real. The model card validates the file and reports it separately from the loaded engine. Clearing history leaves an empty install empty. Privacy groups Archived chats and the Permissions stub. The back control is the shared borderless `WorkspaceBackButton`. RN settings toggles are not ported (**gap**). |
| `_EmptyChat` | `chat_screen.dart` | Real | Shown for a new, unsaved chat. |
| `_LoadingMessages`, `_ChatError` | `chat_screen.dart` | Real | Async loading/retry states. |

## Chat

| Component | File | Status | Notes / stub work |
| --- | --- | --- | --- |
| `ChatController` / `ChatState` | `lib/features/chat/chat_controller.dart` | Real | Session CRUD, per-session messages, streaming send, cancellation, typed reply failures and retry, pin, rename, archive/restore, delete, reset. History is mapped through `ConversationContextBuilder`; the assistant turn is persisted only after a successful stream. Editing a prompt deletes that turn and every later turn before saving the replacement. Retry regenerates without re-saving the user turn. |
| `ConversationContextBuilder` | `lib/features/chat/conversation_context.dart` | Real | Maps one session's persisted user/assistant turns into an `AiRequest` in stored order, omitting empty and attachment-only turns. Rejects history that does not end in a user turn. |
| `MessageList` | `lib/features/chat/widgets/message_list.dart` | Real | RN spacing, user bubble, no assistant bubble, thinking row, streamed partial assistant output, reply-failure row with retry, auto-scroll hooks. |
| `_UserMessage` | same file | Real | Rounded bubble painted by `Material`, with a full-bubble `InkWell` press/focus ripple. Long-press menu has a message-time header, Copy, Edit message. Edit enters a persistent edit mode and shows the restart warning above the composer. |
| `_AssistantMessage` | same file | Real | Markdown plus response actions. |
| `ResponseActions` | `lib/features/chat/widgets/response_actions.dart` | Real / Stub | Copy is real with a 2 s confirmation; Share opens the native share sheet through `share_plus`. Each icon has a transparent Material ink surface with focus/hover/press feedback. Read-aloud is a stub (no TTS model); More reports the missing response menu. |
| `_ThinkingRow`, `_StreamingMessage`, `_ReplyFailureRow` | `message_list.dart` | Real | Pending-reply affordance, streamed markdown, and a user-safe failure with a retry action when retryable. |
| `MarkdownView` | `lib/features/chat/widgets/markdown_view.dart` | Real | GFM, tables, code highlighting, LaTeX. Links open a stub snackbar instead of a browser. |
| `MessageAttachmentList` | `lib/features/chat/widgets/attachment_view.dart` | Real | Renders persisted sent attachments. |
| `KrithaAvatar` | `lib/features/chat/widgets/kritha_avatar.dart` | Real | Logo avatar used outside the chat transcript. |

## Composer

| Component | File | Status | Notes / stub work |
| --- | --- | --- | --- |
| `ChatComposer` | `.../composer/chat_composer.dart` | Real | Switches normal composer → dictation bar → Live Talk. |
| `ComposerNotifier` / `ComposerState` | `.../composer_controller.dart` | Real | Draft, measured lines, latched expansion, attachments, Live Talk phase, editing message id. No animation on expansion. |
| `NormalComposer` | `.../normal_composer.dart` | Real | 17 px input, multiline Enter, bounded height, compact/expanded layouts, focus retention, edit-draft sync, closable “Editing this message will restart…” warning above the capsule. |
| `ComposerAttachmentStrip` | `.../attachment_view.dart` | Real | Image thumbnails and file tiles with removal. |
| `showAttachmentMenu` / `_pick` | `.../composer_controls.dart` | Real | Shared context menu; Photos and Files use `file_picker`. Camera, Plugins and Think harder are disabled stubs. |
| `PlusButton`, `VoiceModeButton`, `ComposerActionButton` | `.../composer_controls.dart` | Real | Attach, start dictation, send / Live Talk / busy states. |
| `AttachmentPicker` | `.../attachment_picker.dart` | Real | Platform file/image picking, MIME inference, size read. Files are referenced, not copied into app storage (**gap**). |
| `DictationNotifier` / `DictationState` | `lib/features/chat/dictation_controller.dart` | Real capture / Stub transcription | Real microphone recording, amplitude metering, cancel, transcribing phase and temp-file cleanup. `transcribe()` is the single STT seam; it currently reports that no local model is bundled and never attaches the recording to the message. |
| `DictationBar` | `.../composer/dictation_bar.dart` | Real (visual) | Frosted composer chrome, X cancel, Flexiyo waveform, square stop-and-transcribe, arrow stop-transcribe-and-send, and a “Transcribing…” state. |
| `RecordingWaveform` | `.../composer/recording_waveform.dart` | Real | Flexiyo-derived metering: newest bars right, 42-bar cap, 3 px light-grey bars (`waveformBar`) with a 4 px gap, 26 px height, paused fade. Responsive bar count for 320 px. |
| `LiveTalkBar` | `.../composer/live_talk_bar.dart` | Visual | Listening/paused states, pause/resume and end are real state transitions. The centre `LiveTalkPill` glows with a fluid 2.4 s loop; paused settles to a dim static state. Video and screen sharing are stubs; no STT/TTS runtime. |
| `LiveTalkPill` | `.../composer/live_talk_pill.dart` | Visual | Animated blue/cyan radial blobs and a moving level wave inside the 50 px capsule. Motion is synthetic while the Live Talk runtime is absent; do not treat it as real microphone metering. |

## Shared widgets

| Component | File | Status | Notes |
| --- | --- | --- | --- |
| `isNetworkUnavailable` | `lib/core/network/dio_error_utils.dart` | Real | Shared classification for Dio connection/time-out failures; catalogue and provider layers keep their own domain-specific status/error messages. |
| `SecureStorageService`, `PlatformSecureStorageService` | `lib/core/storage/secure_storage_service.dart` | Real | One platform secure-storage mechanism shared by the Hub token, provider credentials and runtime probe. Feature stores retain separate keys and behavior. |
| `showKrithaContextMenu`, `ContextMenuItem` | `lib/widgets/context_menu.dart` | Real | React Native geometry/motion: 200 px wide, 48 px middle rows, 24 px radius, 8 px gap, fade + scale from the nearest corner, disabled/destructive states. First/last rows are 56 px and own an 8 px outer edge inset inside their press surface, so there is no surface gutter, the content clears the rounded corners, and no separator rule is needed. Used by the composer attachment picker, header ellipsis, user-message long press and sidebar session long press. `requestFocus: false` keeps the composer keyboard open; with the keyboard up the menu stays fully above the IME (Android hides anything drawn inside the keyboard rectangle), ChatGPT-style. Auto-aligned sidebar menus accept a right boundary; message menus align right. |
| `goBackOrExit`, `goBackOrExitRouter` | `lib/widgets/back_navigation.dart` | Real | Workspace back buttons pop the GoRouter stack instead of hard-coding a destination; Android system back uses the same stack, an app-level Escape shortcut invokes the same action on desktop, and a missing previous route delegates to `SystemNavigator.pop`. |
| `KrithaGlassSurface` | `lib/widgets/glass_surface.dart` | Real | Rounded translucent surface with `BackdropFilter` blur; used by the normal composer and dictation bar. The composer floats over the transcript and the message list reserves its measured height. |
| `buildKrithaTheme` / token classes | `lib/core/theme.dart` | Real | Single source for colours, type, spacing, radii, dimensions, motion. The palette has light and dark values; System/Light/Dark is persisted and applied instantly through `watchKrithaPalette`. DM Sans 400/500/600/700 is bundled and owns `ThemeData.fontFamily`; the theme text styles own `textPrimary` as the default colour. Normal component text inherits both, with local family/colour only for secondary, muted, hint, disabled, destructive or monospace exceptions. |
| `KrithaViewport` | `lib/core/responsive.dart` | Real | Width-only breakpoints at 600 / 840. |

## Data, models and services

| Component | File | Status | Notes |
| --- | --- | --- | --- |
| `AppDatabase` | `lib/data/app_database.dart` | Real | Drift schema v3; v2→v3 migration adds `chat_sessions` and `chat_entries.sessionId`; orphan messages are adopted into “Earlier conversation”. |
| `ChatSession` | `lib/models/chat_session.dart` | Real | Plain model for a sidebar session. |
| `ChatMessage` | `lib/models/chat_message.dart` | Real | Freezed + JSON; role, text, timestamp, attachments. |
| `ChatAttachment` | `lib/models/chat_attachment.dart` | Real | Image/file kind, path, size, MIME, readable size. |
| `RuntimeProbe` | `lib/services/runtime_probe.dart` | Real | Best-effort probes for sherpa-onnx, ONNX Runtime, SQLite, secure storage, prefs, mic, recorder, player, documents. |
| `databaseProvider`, `runtimeStatusProvider`, `dioProvider` | `lib/core/providers.dart` | Real | `dioProvider` is configured but unused by design. |

## Intelligence (Phase 2 wiring)

Chat sends through the engine when a validated model file is configured. No
model ships with the app, nothing loads at startup, and no real generation has
been verified in this workspace.

| Component | File | Status | Notes |
| --- | --- | --- | --- |
| `AiMessage`, `AiRole`, `AiGenerationOptions`, `AiRequest` | `lib/features/intelligence/models/ai_request.dart` | Real (contract) | Freezed + JSON. Text turns, sampler options, optional response schema, optional `modelId`, string metadata. `requiredCapabilities` derives text + structured output. |
| `AiResponse` | `lib/features/intelligence/models/ai_response.dart` | Real (contract) | Text, model id, measured latency, string metadata. Unary generation returns a completed response; stream events are cumulative partial snapshots and only a normally closed stream signals completion. No runtime types, no invented token counts. |
| `ModelCapabilities` | `lib/features/intelligence/models/model_capabilities.dart` | Real (contract) | Declared, not probed. Empty by default; `textOnly` is the only shipped declaration. LiteRT-LM 0.0.14 cannot introspect modality support. |
| `ModelDescriptor` | `lib/features/intelligence/models/model_descriptor.dart` | Real (contract) | Identity, display name, runtime id, capabilities and optional path. No handles, engine or download state. |
| `IntelligenceException` hierarchy | `lib/features/intelligence/intelligence_exception.dart` | Real | Sealed `Exception` types: unavailable provider, unsupported capability, invalid request, failed inference. |
| `InferenceProvider`, `EngineLifecycle` | `lib/features/intelligence/inference_provider.dart` | Real (contract) | `id`, `descriptor`, observable lifecycle, `isInitialized`, `initialize/generate/stream/dispose`. Lifecycle distinguishes file-ready, initializing, loaded, failed, unavailable and disposed without implying inference success. Stream events carry cumulative text; cancelling the subscription stops generation. |
| `AiRequestValidator` | `lib/features/intelligence/request_validation.dart` | Real | Checks message presence, non-empty text, system-message ordering, final user turn, optional model id and sampler bounds before routing or native execution. Capability checks stay in the router and provider. |
| `RequestRouter` | `lib/features/intelligence/request_router.dart` | Real | Empty list → unavailable; optional `modelId` match; first provider declaring every required capability wins. No fallback or retry. |
| `IntelligenceEngine`, `IntelligenceStatus` | `lib/features/intelligence/intelligence_engine.dart` | Real (contract) | Runs `AiRequestValidator`, then delegates unary and streaming calls to the router. Status reports configured/loaded and the engine lifecycle only, never successful inference. |
| `ModelLifecycle` | `lib/features/intelligence/model_lifecycle.dart` | Real (derived) | Combines file validation with the engine lifecycle for Settings. Reports checking, not configured, file unavailable, file ready, loading, loaded, initialization failed, unavailable and released; never claims a successful generation. |
| `ModelConfiguration`, `ModelConfigurationController`, `ModelConfigStore` | `lib/features/intelligence/model_configuration.dart` | Real | Persists the picked path in SharedPreferences; distinguishes not configured, missing, invalid, unavailable and ready. Validates extension, file type and non-empty size before the runtime sees it. Serializes writes and revision-guards slow reads. No download or marketplace. |
| `LiteRtLmProvider`, `NativeLiteRtLmEngine` | `lib/features/intelligence/runtimes/litertlm_provider.dart` | Adapter, unverified with weights | All `litertlm` imports live here. Validates request invariants, model selection and declared capabilities before native work; rejects structured output explicitly. Lazy engine init, explicit lifecycle, one conversation per request, sampler/role mapping, cumulative streaming, immediate cancellation through explicit stream controllers, typed error translation, engine discarded after failure. Never exercised with a real model. |
| `modelConfigStoreProvider`, `modelConfigurationProvider`, `configuredModelProvider`, `liteRtLmEngineFactoryProvider`, `inferenceProvidersProvider`, `requestRouterProvider`, `intelligenceEngineProvider`, `modelLifecycleProvider`, `intelligenceStatusProvider` | `lib/features/intelligence/providers.dart` | Real | Model is validated before it reaches the router; engine factory is overridable so tests never load native code. Diagnostics observe provider lifecycles without initializing a runtime. |

## Models and Providers

The Models workspace is Hub discovery plus an honest local assignment layer. It
does not download, load or verify a Hub repository.

| Component | File | Status | Notes |
| --- | --- | --- | --- |
| `CatalogueModel`, `ModelDetails`, `ModelFile`, `ModelCapability`, `CatalogueSort` | `lib/features/models/catalogue/catalogue_model.dart` | Real (parsing) | Maps `/api/models`, `?full=true`, the recursive tree and README metadata. List requests expand `safetensors` so cards show the real parameter total when the Hub publishes one; the count is never inferred from a repository name. Capabilities are derived from `pipeline_tag`/tags; they are Hub declarations, not runtime probes. |
| `HuggingFaceHubClient`, `parseNextCursor` | `lib/features/models/catalogue/hugging_face_hub_client.dart` | Real | Dedicated Dio transport with no request logging. Public requests omit auth; a saved token is sent as `Authorization: Bearer` only to `huggingface.co`. Search/filter/sort/limit/cursor, model record, file tree, README and `whoami-v2` validation. |
| `ModelCatalogue`, `ModelCatalogueRepository` | `lib/features/models/catalogue/model_catalogue_repository.dart` | Real | UI-facing search/details/validation surface, separate from widgets and inference providers. |
| `CatalogueController`, `FeaturedCatalogueController`, `modelDetailsProvider` | `lib/features/models/catalogue/catalogue_controller.dart` | Real | Search state, append pagination, retry, cancellation and stale-response revision guards. Featured loads most-downloaded and most-liked lists. |
| `HuggingFaceTokenStore`, `HuggingFaceTokenController` | `lib/features/models/token/` | Real | Uses the shared platform secure-storage service. Saves only after validation; a rejected token is not stored, an offline validation saves with an explicit unverified notice. State never contains the token. |
| `ActiveModelAssignment`, `ActiveModelsController` | `lib/features/models/active/active_models.dart` | Real | SharedPreferences assignments keyed by capability, sourced from local inventory or a connected provider. Only the validated local LiteRT-LM text path has an execution path; provider-hosted assignments are saved without claiming chat routing. Stale assignments remain visible with remove/choose actions. Chat still uses the Settings selection; multi-model routing is not implemented. |
| `ModelsScreen` | `lib/features/models/models_screen.dart` | Real | Explore default, search debounce, capability chips, an anchored sort menu in the search field, featured sections, compact model cards with task/parameter/updated/download/like metadata, pagination and offline/rate-limit/unauthorized/empty states. The header filter action opens Active Models; the ellipsis menu opens the token dialog and the disabled Pro custom-catalogue entry. |
| `ModelDetailsScreen` | `lib/features/models/model_details_screen.dart` | Real | Metadata, capabilities, requirements, file tree and README/model card. Explicitly separates discovery from verified runtime compatibility; activation remains unavailable until a file is local and validated. |
| `ActiveModelsScreen` | `lib/features/models/active_models_screen.dart` | Real | Per-capability slots with assigned/ready/stale/not-assigned status, assignment actions and a clear no-download/no-load notice. |
| `CustomCatalogueScreen` | `lib/features/models/custom_catalogue_screen.dart` | Stub (gated) | Pro explanation only; no endpoint, schema or billing logic. |

Providers configure inference connections separately from Hub discovery.

| Component | File | Status | Notes |
| --- | --- | --- | --- |
| `InferenceProviderDefinition`, `supportedInferenceProviders` | `lib/features/providers/provider_definition.dart` | Real (registry) | Local LiteRT-LM, OpenAI, Anthropic, Google Gemini, Mistral and a custom OpenAI-compatible endpoint. |
| `ProviderSettingsStore`, `ProviderCredentialStore` | `lib/features/providers/provider_stores.dart` | Real | Endpoints and a configured flag in SharedPreferences; credentials use the shared secure-storage service under provider-specific keys. Hub tokens retain a different store and key. |
| `HttpProviderConnectionTester` | `lib/features/providers/provider_connection_tester.dart` | Real | Performs a real GET to the provider's models endpoint and reports status, model count or a user-safe failure. No response body or credential is echoed. |
| `ProvidersController`, `ProvidersState` | `lib/features/providers/providers_controller.dart` | Real | Derived connection state, endpoint edits, credential save/remove, local model check and connection-test results. Provider routing into chat is not implemented. |
| `ProvidersScreen` | `lib/features/providers/providers_screen.dart` | Real | Compact provider cards with Connect dialogs, an overflow menu for test/remove, a header action for the custom endpoint and test results. Saved secrets are never repopulated into fields. |

## Working interactions (manual checklist)

- Create a chat: New chat → empty state → first prompt creates a session titled
  from the prompt.
- Switch session: tap any Pinned/Recents row; the drawer closes and that
  session's messages load.
- Pin/unpin: long-press a session → Pin/Unpin; the row moves between sections.
- Rename: long-press → Rename → dialog; title persists.
- Archive: long-press → Archive; chat leaves Recents and appears in Archived
  chats. Open Archived chats from Settings → Privacy to restore or delete.
- Delete: long-press → Delete; the session and its messages are deleted. If it
  was open, the newest remaining session is selected.
- Attachments: plus → Photos/Files; previews can be removed; attachments
  persist with the sent message.
- Dictation: mic → real recording with Flexiyo-style waveform → X cancels;
  square stops and attempts transcription; arrow stops, transcribes and sends.
  The “Transcribing…” state is shown while stopping. No audio file is attached;
  without a bundled STT model the action reports the missing model and the temp
  file is deleted.
- Live Talk: send action on an empty composer → capsule starts → pause/resume →
  X returns to the composer.
- Message menu: long-press a user bubble → Copy / Edit message.
- Edit a prompt: Edit message loads the text and shows a persistent warning above
  the composer. Sending deletes that turn and every later turn, then appends the
  replacement and a new reply. The X cancels the edit and clears the draft.
- Clear local history: Settings → Clear local history asks for confirmation,
  then clears sessions and messages. Fresh installs and cleared installs stay
  empty; no demo fixture is seeded.

## Left functions / stubs

Ordered roughly by value for the next cloning pass. Each row is a concrete
hand-off: the visible entry point already exists where noted.

| # | Feature | Entry point / function | Current behaviour | Needed |
| --- | --- | --- | --- | --- |
| 1 | Assistant inference with a real model | `ChatController.send` → `intelligenceEngineProvider` | Wired: validated model selection, persisted history mapping, streaming, cancel, retry and user-safe failures. No model ships and no real generation has been verified. | Pick and validate an actual `.litertlm` file on a device, confirm native streaming/cancel semantics and tune prompts/samplers. Per-request conversations replay history; conversation reuse is deferred. |
| 2 | Dictation transcription | `DictationNotifier.transcribe` | Stops and deletes the take, then raises a missing-model error; never attaches audio. | Pass the stopped file through sherpa-onnx/STT, return text so the square inserts it and the arrow sends it, keep the error surface. |
| 3 | Live Talk runtime | `LiveTalkBar`, `ComposerNotifier` phases | Visual pulse and pause/resume only. | Mic session, VAD, STT, LLM turn taking, TTS playback, real phase transitions. |
| 4 | Read aloud | `_AssistantMessage` → `ResponseActions.onSpeak` | Snackbar says TTS is unbundled. | Downloadable voice models + `just_audio` playback controls. |
| 5 | Camera attachment | `showAttachmentMenu` `'camera'` | Visible, disabled. | Camera permission/capture, image attachment, storage copy. |
| 6 | Plugins | `showAttachmentMenu` `'plugins'` | Visible, disabled. | Plugin picker and attachment/tool contract. |
| 7 | Think harder | `showAttachmentMenu` `'think'` | Visible, disabled. | Reasoning-mode flag plumbed into the engine request. |
| 8 | Library | Sidebar `Library` | Stub snackbar. | RN Library screen and its data source. |
| 9 | Plugins | Sidebar row | Stub snackbar. | Plugin management. |
| 10 | Permissions | Settings → Privacy | Stub snackbar. | Per-capability permission panel (mic, camera, photos, notifications). |
| 11 | More | Sidebar row | Stub snackbar. | Remaining RN account/menu actions. |
| 12 | Chat search | Sidebar search icon | Stub snackbar. | SQLite FTS or in-memory filter across titles/messages. |
| 13 | Attachment storage | `FileAttachmentPicker` / send | Stores the picker path only. | Copy into app documents and delete on session removal. |
| 14 | Message pagination | `AppDatabase.messagesForSession` | Loads every message. | Windowed queries for long conversations. |
| 15 | Markdown links | `MarkdownView.onTapLink` | Stub snackbar. | Route through `url_launcher` with allow-listing. |
| 16 | Wake word | `SettingsScreen` → Voice | Real Android foreground-service toggle. | iOS/desktop runtime and a model picker. |
| 17 | Account identity | Sidebar footer → account menu | Static “Kaushal Krishna / KK” with Free, Profile, Settings and Log out entries; only Settings is wired. | Profile source, plan data and real account actions. |
| 18 | Settings depth | `SettingsScreen` | Probes, local model selection/removal and confirmed history clearing. | Remaining RN toggles and richer model metadata. |
| 19 | Backend/network | `dioProvider` | Configured, unused. | Auth, sync, remote models, request logging. |
| 20 | Multimodal prompts | `AiRequest` / composer attachments | Attachments persist and render, but only text is sent; attachment-only prompts fail with a clear message. | Image/audio content parts, capability checks and runtime support. |
| 21 | Custom catalogue | Models ellipsis menu → Custom catalogue (Pro) | Gated explanation screen; no endpoint or schema work. | Plan/billing gate, endpoint configuration and a response-schema adapter. |
| 22 | Hosted provider routing | Providers workspace | Providers can be connected, configured and tested, but chat still uses the local engine. | Route `intelligenceEngineProvider` through the connected provider, map streaming/cancel/errors and add capability checks. |
| 23 | Hub model download and activation | Model details → Active Models | Details and assignments are real; activation is limited to an already validated local `.litertlm` file. | Verified download with progress, checksum, storage policy, runtime compatibility probes and per-capability engines. |

## Component docs checklist

When a stub above is implemented, update:

1. The status row in this file.
2. `README.md` → “What is implemented” and “Known gaps”.
3. The relevant widget/controller doc comment.
4. The matching rule in `docs/DESIGN_CONVENTIONS.md`, `docs/BUTTONS.md` or
   `docs/UI_PATTERNS.md` if the component's geometry, states or pattern changed.
5. A regression test (`test/chat_controller_test.dart`,
   `test/foundation_test.dart`, `test/models_catalogue_test.dart`,
   `test/models_token_test.dart`, `test/active_models_test.dart`,
   `test/providers_test.dart`, `test/models_ui_test.dart`, or a new focused
   test).
