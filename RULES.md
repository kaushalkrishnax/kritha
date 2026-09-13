# Kritha — Architectural Rules

Status: **Binding**. Every phase prompt in `phases/` assumes these rules.
If a phase prompt ever conflicts with this file, this file wins — stop and
ask before proceeding.

This file answers "who is allowed to do what." `CONVENTIONS.md` answers
"where does the file go and what is it called." Read both before touching
code.

---

## 0. The One-Sentence Version

**JS/TS is Kritha. Kotlin is a box of tools Kritha uses.**

JS/TS decides what happens, when it happens, and what it means. Kotlin
executes a request and reports back. Kotlin never decides anything on its
own behalf.

---

## 1. Ownership Boundary

### 1.1 JS/TS owns (exclusively)

- Assistant orchestration (what happens after the user taps something)
- All canonical runtime state (`stores/assistant.store.ts`)
- Conversation construction (system prompt, history, custom instructions)
- Provider selection (which LLM/STT/TTS implementation handles a request)
- Request construction (turning app state into a provider request)
- Persistence policy (when a message is saved, when a session is created)
- All UI-facing behavior and derived state

### 1.2 Kotlin owns (exclusively)

- Executing local LLM inference when asked, given a fully-formed
  prompt/message list
- Executing native device tool commands (torch, mute, settings, dialer)
- Owning Android platform capabilities JS cannot reach directly:
  microphone ownership during wake-word listening, notification listener
  registration, voice interaction session hosting, foreground service
  lifecycle
- Reporting results and progress back to JS via well-defined events

### 1.3 Forbidden in Kotlin — for all time, not just this refactor

Do not add, and do not resurrect from git history:

- Any class named `*Orchestrator`, `*AssistantRuntime`,
  `*ConversationManager`, `*AssistantSessionManager` (this refers to
  assistant-conversation session state, not Android's own
  `VoiceInteractionSession`, which is a legitimate platform concept and is
  not affected by this rule)
- Any code that decides *whether* to use the local model vs. the cloud
  model
- Any code that constructs a system prompt, builds chat history, or
  decides what "context" to send to a model
- Any code that decides when the assistant should speak, listen, or
  respond
- Any code that stores conversation messages beyond the transient buffers
  a single request needs to run

If a Kotlin file starts to need any of the above, the fix is **always** in
JS. Move the decision to JS and have JS tell Kotlin exactly what to do.

### 1.4 Forbidden in JS — native concerns stay native

- Do not implement raw audio capture, wake-word inference, or on-device
  model execution in JS. These stay behind the Kotlin provider boundary.
- Do not reach into Android system settings/intents from JS except
  through the existing Expo module (`AssistantBridge` and friends).

---

## 2. Single Source of Truth for Runtime State

### 2.1 `stores/assistant.store.ts` is the only place ephemeral,
cross-cutting assistant runtime state lives

"Ephemeral, cross-cutting" means: it describes *what the assistant is
doing right now* and is meaningless after an app restart. Examples: is the
LLM generating, is STT listening, what chat mode is active, what the
in-flight run's transcript/response/error is.

### 2.2 What does NOT belong in `assistant.store.ts`

- Persisted user preferences (settings, selected model, selected voice
  models) → their own `*.store.ts` files, each with an explicit
  `partialize`.
- Conversation data that survives a restart (sessions, messages) →
  `stores/chat.store.ts`, backed by the SQLite layer in `database/`.
- A single component's private, one-off UI concern (e.g. is a modal's
  internal dropdown open) → local `useState` in that component.

### 2.3 `assistant.store.ts` is never persisted

No `persist()` middleware, ever, on this store. Resuming a stale
`LLM_GENERATING` or `STT_LISTENING` state after a process restart is a
bug, not a feature. On boot this store always starts at its defined
initial state.

### 2.4 Imperative handles never live in a store

Cancel functions, timers, subscriptions, `AbortController`s — anything
that isn't plain serializable data — must not be put inside a Zustand
store. They live as module-level variables inside the service that owns
them (e.g. the in-flight LLM cancel handle lives inside
`services/assistantRuntime.service.ts`, not inside `assistant.store.ts`).

---

## 3. Canonical States

### 3.1 Canonical state constants live only in
`constants/canonicalStates.ts`

No component, hook, or service may define its own string literals for
these states (`"GENERATING"`, `"listening"`, etc). Always import the
constant.

### 3.2 Domains are independent — never collapse into one flat enum

The assistant can be `LLM_GENERATING` **and** `STT_LISTENING` **and**
`CHAT_MODE_LIVE_TALK` at the same time (barge-in during Live Talk). A
single flat `canonicalState: string` cannot represent that — this is
exactly why the old `assistantSessionStore.canonicalState` design is being
replaced. Each domain gets its own field:

| Domain | Field | Values live in |
|---|---|---|
| LLM lifecycle | `llmPhase` | `LlmPhase` |
| STT lifecycle | `sttPhase` | `SttPhase` |
| TTS lifecycle | `ttsPhase` | `TtsPhase` |
| Chat mode | `chatMode` | `ChatMode` |
| Live Talk sub-phase | `liveTalkPhase` | `LiveTalkPhase` (nullable — only meaningful while `chatMode === ChatMode.LIVE_TALK`) |

### 3.3 Components never import `canonicalStates.ts` to compare phases directly

Forbidden, inside any `.tsx` file:

```tsx
if (canonicalState === 'GENERATING') { ... }
```

Required instead — call a selector hook exported by
`stores/assistant.store.ts`:

```tsx
const isGenerating = useIsLlmGenerating();
```

**Clarification:** this restriction is about the five *phase* fields
listed in §3.2. Plain data fields on the same store — `response`,
`transcript`, `error`, `draftText`, `requestOrigin`, `volumeRms`,
`currentTtsMessageId` — are not state machines, and a component may read
them directly (`useAssistantStore((s) => s.response)`). A component may
also combine several already-derived selector results with plain boolean
logic (e.g. `isThinking && requestOrigin === RequestOrigin.WAKE_WORD`) —
that is not "comparing a raw phase," it's composing already-typed
selector output, which is fine.

### 3.4 Only selectors may read raw phases

Raw phase fields (`llmPhase`, `sttPhase`, `ttsPhase`, `chatMode`,
`liveTalkPhase`) may be read directly by:
- Selector functions defined in `stores/assistant.store.ts` itself
- `services/assistantRuntime.service.ts` (it's the thing setting them)

Everyone else consumes selectors.

---

## 4. High-Level Functions ("Verbs")

### 4.1 The fixed verb list

`submitPrompt`, `cancelRun`, `startDictation`, `cancelDictation`,
`stopDictation`, `sendDictation`, `startLiveTalk`, `pauseLiveTalk`,
`resumeLiveTalk`, `stopLiveTalk`, `speakMessage`, `stopSpeaking`.

Do not invent additional verbs without adding them to this list first.
Each verb name is written the way a user would describe the button they
tapped ("I hit send," "I started dictating"). If you can't finish the
sentence *"the user just ___"* with the function name, the name is wrong.

### 4.2 Only these functions may write `llmPhase` / `sttPhase` / `ttsPhase`
/ `chatMode` / `liveTalkPhase`

They live in `services/assistantRuntime.service.ts`. No hook, no
component, no other service may call
`useAssistantStore.getState().setLlmPhase(...)` (or any equivalent
setter) directly. Route everything through a verb.

### 4.3 Hooks and components call verbs; they never construct transitions

A hook like `useChatInput` is allowed to call
`assistantRuntime.submitPrompt(...)`. It is not allowed to call
`setLlmPhase(LlmPhase.SUBMITTING)` itself, even if it "just wants to show
a spinner a little early." That's what the verb already does.

---

## 5. Providers

### 5.1 Provider contract is fixed; runtime code is provider-agnostic

`assistantRuntime.service.ts` calls `LlmProvider.generate(...)`,
`SttProvider.startListening(...)`, `TtsProvider.speak(...)` — it never
branches on "is this the local model or the cloud model." That branch
happens exactly once, in the provider registry.

### 5.2 Provider selection logic lives in ONE place

`services/providers/llm/index.ts` exports `pickLlmProvider(modelId)`.
This is the only function in the entire codebase allowed to contain
`if (model.isCloud) { ... } else { ... }` for LLM routing. The same
pattern applies to `services/providers/stt/index.ts` and
`services/providers/tts/index.ts` once either grows a second
implementation.

### 5.3 Adding a provider must never touch the runtime service

If implementing a new provider requires editing
`assistantRuntime.service.ts`, the provider interface is wrong — fix the
interface, not the runtime.

---

## 6. Error Handling & Cancellation

### 6.1 Every async verb wraps its body in try/catch

On failure: set the relevant phase to its `*_ERROR` value, route a
human-readable message into `assistant.store.ts`'s `error` field, and
always return the phase to a safe resting state (`IDLE` for that domain)
so the UI is never stuck showing a spinner forever.

### 6.2 `assistantRunId` guard pattern

Every call to `submitPrompt` (and every Live Talk turn) generates a new
`assistantRunId` (a `uuid`, via the `uuid` package already used in
`database/`) and stores it in `assistant.store.ts`. Any asynchronous
callback (provider `onDelta`/`onComplete`/`onError`, native event) must
compare the run id it was given against
`useAssistantStore.getState().assistantRunId` before applying its result.
If they don't match, the callback is stale — drop it silently. This is
how a cancelled/superseded run is prevented from finishing late and
corrupting the new run's UI state. The same pattern applies on the Kotlin
side using `requestId` (see §9.3).

### 6.3 Errors are routed to the store, never thrown into a UI event handler

`onPress={() => runtime.submitPrompt(...)}` must never be able to throw.
`submitPrompt` and every other verb catch everything internally.

---

## 7. Persistence Rules

| Store | Persisted? | Storage |
|---|---|---|
| `stores/assistant.store.ts` | **Never** | n/a |
| `stores/chat.store.ts` | Messages/sessions come from SQLite (`database/`); the Zustand store is an in-memory mirror, not a persist target. | n/a |
| `stores/model.store.ts` | Yes — `selectedModelId` only | MMKV |
| `stores/settings.store.ts` | Yes — all fields | MMKV |
| `stores/voice.store.ts` | Yes — `selectedSttModelId`, `selectedTtsModelId` only | SecureStore |
| `stores/wakeword.store.ts` | No (re-derived from the native module on boot) | n/a |

Every `persist()` call must include an explicit `partialize`. Never
persist an entire store "for convenience."

---

## 8. Data Flow Direction
User taps something
|
v
Component (.tsx) — no logic, just calls a hook function
|
v
Hook (hooks/useX.ts) — thin, forwards to a runtime verb, no business logic
|
v
services/assistantRuntime.service.ts — the verb. Talks to providers,
conversation service, chat service, and assistant.store.ts setters.
|
v
stores/assistant.store.ts — raw phases + data updated
|
v
Selector (in the same store file) — computes a UI-shaped value
|
v
Component re-renders via the selector hook


**Exception:** setting `draftText` while the user is typing is a plain,
non-orchestration write and may be called directly from `ChatInput` via
the store's `setDraftText` action. Typing a character is not a phase
transition. Starting or stopping a flow always is.

---

## 9. Kotlin Contract Rules

### 9.1 Every native `Function`/`Event` is documented at the top of `KrithaModule.kt`

A short comment block above `ModuleDefinition` lists every exposed
function/event, its JS-facing signature, and one sentence of what it
does. Keep this list current — it's the map JS developers use instead of
reading Kotlin.

### 9.2 Kotlin must not import conversation, prompt-construction, or
provider-selection logic

A Kotlin generation request receives an already-built message list.
Kotlin may translate it into whatever format the underlying SDK (LiteRT)
wants (concatenation, a chat template, whatever the SDK provides), but it
does not decide what messages belong in the list and does not
truncate/summarize history — that is a JS policy decision.

### 9.3 Streaming events always carry a `requestId`

So JS can apply the same stale-response guard described in §6.2 on the
native side too. An event that can't be tied back to a request id is a
bug.

### 9.4 Every long-running native `Function` is cancellable

If it can take more than roughly a second, it needs a companion cancel
path — either a matching `cancelXxx(requestId)` Function, or the
underlying coroutine `Job` keyed by `requestId` in a module-level map.

---

## 10. Stub Rules

### 10.1 Every stub is labeled

Any temporary/fake implementation carries a `// STUB:` comment directly
above it, one sentence explaining what real behavior it stands in for and
which phase file replaces it.

### 10.2 Stubs still drive canonical state correctly

A stub for STT/TTS is not allowed to skip phase transitions "because it's
fake." The rest of the app must not be able to tell the difference
between a stub and the real thing from the outside. If `startDictation()`
is stubbed, `sttPhase` must still go `IDLE -> LISTENING`, and
`stopDictation()` must still go `LISTENING -> TRANSCRIBING -> IDLE`, on
realistic timers.

### 10.3 Stubs never fabricate believable fake content

A stub STT provider that has no real audio input returns an empty
transcript, not an invented sentence. Inventing plausible-looking fake
data hides bugs later; an honestly-empty result is easy to reason about.

---

## 11. Change Management

- Adding a new canonical state, a new store, or a new verb requires
  updating this file (§3.2 table, §7 table, or §4.1 list respectively) in
  the same change. A code change that adds a new phase/store/verb without
  a matching `RULES.md` update is incomplete.
- If a future need genuinely requires breaking one of these rules, write
  the new rule down here with the reasoning — don't leave it as a silent
  exception in one file.