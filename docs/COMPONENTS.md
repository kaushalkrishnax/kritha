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
| `ChatSidebar` | `lib/features/chat/widgets/chat_sidebar.dart` | Real | SQLite sessions, Pinned/Recents, six contiguous 56 px top action rows (no inter-item gap), 24 px Lucide 600-weight action icons, 56 px session rows, long-press menu, rename dialog, archive list, settings/account strip. |
| `_ArchivedSessionsDialog` | same file | Real | Lists archived sessions; restore and delete are persisted. |
| `SettingsScreen` | `lib/features/settings/settings_screen.dart` | Real | Runtime probes and reset history are real. The back control is a 44 px circular ink target with zero internal padding, so its focus/ripple fills the circle. RN settings toggles are not ported (**gap**). |
| `_EmptyChat` | `chat_screen.dart` | Real | Shown for a new, unsaved chat. |
| `_LoadingMessages`, `_ChatError` | `chat_screen.dart` | Real | Async loading/retry states. |

## Chat

| Component | File | Status | Notes / stub work |
| --- | --- | --- | --- |
| `ChatController` / `ChatState` | `lib/features/chat/chat_controller.dart` | Real | Session CRUD, per-session messages, send/save/reply, pin, rename, archive/restore, delete, reset. Editing a prompt deletes that turn and every later turn before saving the replacement. Reply text is a stub. |
| `MessageList` | `lib/features/chat/widgets/message_list.dart` | Real | RN spacing, user bubble, no assistant bubble, thinking row, auto-scroll hooks. |
| `_UserMessage` | same file | Real | Rounded bubble painted by `Material`, with a full-bubble `InkWell` press/focus ripple. Long-press menu has a message-time header, Copy, Edit message. Edit enters a persistent edit mode and shows the restart warning above the composer. |
| `_AssistantMessage` | same file | Real | Markdown plus response actions. |
| `ResponseActions` | `lib/features/chat/widgets/response_actions.dart` | Real / Stub | Copy is real with a 2 s confirmation; Share opens the native share sheet through `share_plus`. Each icon has a transparent Material ink surface with focus/hover/press feedback. Read-aloud is a stub (no TTS model); More reports the missing response menu. |
| `_ThinkingRow` | `message_list.dart` | Real | Animated pending-reply affordance. |
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
| `showKrithaContextMenu`, `ContextMenuItem` | `lib/widgets/context_menu.dart` | Real | React Native geometry/motion: 200 px wide, 48 px middle rows, 24 px radius, 8 px gap, fade + scale from the nearest corner, disabled/destructive states. First/last rows are 56 px and own an 8 px outer edge inset inside their press surface, so there is no surface gutter, the content clears the rounded corners, and no separator rule is needed. Used by the composer attachment picker, header ellipsis, user-message long press and sidebar session long press. `requestFocus: false` keeps the composer keyboard open; with the keyboard up the menu stays fully above the IME (Android hides anything drawn inside the keyboard rectangle), ChatGPT-style. Auto-aligned sidebar menus accept a right boundary; message menus align right. |
| `KrithaGlassSurface` | `lib/widgets/glass_surface.dart` | Real | Rounded translucent surface with `BackdropFilter` blur; used by the normal composer and dictation bar. The composer floats over the transcript and the message list reserves its measured height. |
| `buildKrithaTheme` / token classes | `lib/core/theme.dart` | Real | Single source for colours, type, spacing, radii, dimensions, motion. DM Sans 400/500/600/700 is bundled and owns `ThemeData.fontFamily`; the theme text styles own `textPrimary` as the default colour. Normal component text inherits both, with local family/colour only for secondary, muted, hint, disabled, destructive or monospace exceptions. |
| `KrithaViewport` | `lib/core/responsive.dart` | Real | Width-only breakpoints at 600 / 840. |

## Data, models and services

| Component | File | Status | Notes |
| --- | --- | --- | --- |
| `AppDatabase` | `lib/data/app_database.dart` | Real | Drift schema v3; v2→v3 migration adds `chat_sessions` and `chat_entries.sessionId`; orphan messages are adopted into “Earlier conversation”. |
| `ChatSession` | `lib/models/chat_session.dart` | Real | Plain model for a sidebar session. |
| `ChatMessage` | `lib/models/chat_message.dart` | Real | Freezed + JSON; role, text, timestamp, attachments. |
| `ChatAttachment` | `lib/models/chat_attachment.dart` | Real | Image/file kind, path, size, MIME, readable size. |
| `demoMessages`, `demoReplyFor` | `lib/data/seed_messages.dart` | Stub | Fixture turns and canned reply. Replace with the real engine. |
| `RuntimeProbe` | `lib/services/runtime_probe.dart` | Real | Best-effort probes for sherpa-onnx, ONNX Runtime, SQLite, secure storage, prefs, mic, recorder, player, documents. |
| `databaseProvider`, `runtimeStatusProvider`, `dioProvider` | `lib/core/providers.dart` | Real | `dioProvider` is configured but unused by design. |

## Working interactions (manual checklist)

- Create a chat: New chat → empty state → first prompt creates a session titled
  from the prompt.
- Switch session: tap any Pinned/Recents row; the drawer closes and that
  session's messages load.
- Pin/unpin: long-press a session → Pin/Unpin; the row moves between sections.
- Rename: long-press → Rename → dialog; title persists.
- Archive: long-press → Archive; chat leaves Recents and appears in Archived
  Chats. Open Archived Chats from the sidebar to restore or delete.
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
- Reset: Settings → Reset local history clears sessions and messages, then
  re-seeds the fixture.

## Left functions / stubs

Ordered roughly by value for the next cloning pass. Each row is a concrete
hand-off: the visible entry point already exists where noted.

| # | Feature | Entry point / function | Current behaviour | Needed |
| --- | --- | --- | --- | --- |
| 1 | Real assistant reply | `ChatController.send` → `demoReplyFor` | Canned Markdown reply after 450 ms. | Local LLM or backend call; streaming; error/retry. |
| 2 | Dictation transcription | `DictationNotifier.transcribe` | Stops and deletes the take, then raises a missing-model error; never attaches audio. | Pass the stopped file through sherpa-onnx/STT, return text so the square inserts it and the arrow sends it, keep the error surface. |
| 3 | Live Talk runtime | `LiveTalkBar`, `ComposerNotifier` phases | Visual pulse and pause/resume only. | Mic session, VAD, STT, LLM turn taking, TTS playback, real phase transitions. |
| 4 | Read aloud | `_AssistantMessage` → `ResponseActions.onSpeak` | Snackbar says TTS is unbundled. | Downloadable voice models + `just_audio` playback controls. |
| 5 | Camera attachment | `showAttachmentMenu` `'camera'` | Visible, disabled. | Camera permission/capture, image attachment, storage copy. |
| 6 | Plugins | `showAttachmentMenu` `'plugins'` | Visible, disabled. | Plugin picker and attachment/tool contract. |
| 7 | Think harder | `showAttachmentMenu` `'think'` | Visible, disabled. | Reasoning-mode flag plumbed into the engine request. |
| 8 | Library | Sidebar `Library` | Stub snackbar. | RN Library screen and its data source. |
| 9 | Extensions & Runtimes | Sidebar row | Stub snackbar. | Model/runtime manager; local install/remove; permission state. |
| 10 | Permissions | Sidebar row | Stub snackbar. | Per-capability permission panel (mic, camera, photos, notifications). |
| 11 | More | Sidebar row | Stub snackbar. | Remaining RN account/menu actions. |
| 12 | Chat search | Sidebar search icon | Stub snackbar. | SQLite FTS or in-memory filter across titles/messages. |
| 13 | Attachment storage | `FileAttachmentPicker` / send | Stores the picker path only. | Copy into app documents and delete on session removal. |
| 14 | Message pagination | `AppDatabase.messagesForSession` | Loads every message. | Windowed queries for long conversations. |
| 15 | Markdown links | `MarkdownView.onTapLink` | Stub snackbar. | Route through `url_launcher` with allow-listing. |
| 16 | Wake word | Header runtime slot | Opens runtime screen. | Wake-word service and toggle state. |
| 17 | Account identity | Sidebar footer | Static “Your Name / YN”. | Profile source and editing. |
| 18 | Settings depth | `SettingsScreen` | Probes + reset only. | RN toggles and model management. |
| 19 | Backend/network | `dioProvider` | Configured, unused. | Auth, sync, remote models, request logging. |

## Component docs checklist

When a stub above is implemented, update:

1. The status row in this file.
2. `README.md` → “What is implemented” and “Known gaps”.
3. The relevant widget/controller doc comment.
4. The matching rule in `docs/DESIGN_CONVENTIONS.md`, `docs/BUTTONS.md` or
   `docs/UI_PATTERNS.md` if the component's geometry, states or pattern changed.
5. A regression test (`test/chat_controller_test.dart`,
   `test/foundation_test.dart`, or a new focused test).
