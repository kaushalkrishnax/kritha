# Kritha — Architectural Rules

**Status: Binding**

These are the permanent architectural rules for Kritha.

If another document or implementation conflicts with these rules, these rules take precedence.

`RULES.md` defines **ownership and behavior**.
`CONVENTIONS.md` defines **naming, location, imports, and structure**.

---

## 0. Core Principle

**JS/TS is Kritha. Kotlin is a box of tools Kritha uses.**

JS/TS decides what happens, when it happens, and what it means.

Kotlin executes explicit requests and reports results.

---

## 1. Ownership Boundary

### 1.1 JS/TS owns exclusively

- Assistant orchestration
- Canonical runtime state
- Conversation construction and context
- Provider selection
- Request construction
- Persistence policy
- UI-facing behavior and derived state

The canonical assistant runtime state lives in:

```text
stores/assistant.store.ts
```

### 1.2 Kotlin owns exclusively

- Local LLM execution when given a fully formed request
- Native device/tool commands
- Android platform capabilities
- Wake-word microphone ownership
- Notification listener registration
- Voice interaction hosting
- Foreground-service lifecycle
- Reporting native results, progress, and events

### 1.3 Forbidden in Kotlin

Kritha must never introduce Kotlin classes or logic for:

```text
*Orchestrator
*AssistantRuntime
*ConversationManager
*AssistantSessionManager
```

Also forbidden in Kotlin:

- Local-vs-cloud model decisions
- System-prompt construction
- Conversation-history/context decisions
- Decisions about when the assistant speaks, listens, or responds
- Persistent conversation storage

Kotlin receives explicit instructions from JS rather than making these decisions itself.

### 1.4 Forbidden in JS/TS

Do not implement native concerns in JS/TS:

- Raw audio capture
- Wake-word inference
- On-device model execution
- Direct Android system settings/intents

Use the native module boundary for these capabilities.

---

## 2. Assistant Runtime State

### 2.1 Single runtime store

`stores/assistant.store.ts` is the only store for ephemeral, cross-cutting assistant runtime state.

Examples:

- LLM phase
- STT phase
- TTS phase
- Chat mode
- Live Talk phase
- Current response
- Current transcript
- Current error
- Current run information

### 2.2 What does not belong there

Persisted preferences belong in their domain stores.

Conversation data belongs in `chat.store.ts` and the SQLite database.

Private component state belongs in component-local state.

### 2.3 Runtime state is never persisted

`assistant.store.ts` must never use persistence middleware.

Runtime state must always start from its defined initial state after process restart.

### 2.4 Imperative handles stay outside stores

Never put non-serializable runtime handles in Zustand, including:

- Cancel functions
- `AbortController`
- Timers
- Subscriptions
- Native jobs
- Provider handles

These belong to the service or module that owns them.

---

## 3. Canonical States

### 3.1 Single source of truth

Canonical state definitions live only in:

```text
constants/canonicalStates.ts
```

Do not recreate these states as string literals elsewhere.

### 3.2 Independent state domains

Never represent the assistant with one flat state.

| Domain        | Field           |
| ------------- | --------------- |
| LLM lifecycle | `llmPhase`      |
| STT lifecycle | `sttPhase`      |
| TTS lifecycle | `ttsPhase`      |
| Chat mode     | `chatMode`      |
| Live Talk     | `liveTalkPhase` |

These domains are independent and may be active simultaneously.

### 3.3 UI access

Components must not compare raw canonical phase values directly.

Use selectors exposed by `stores/assistant.store.ts`:

```tsx
const isGenerating = useIsLlmGenerating();
```

Plain data such as `response`, `transcript`, `error`, `draftText`, `requestOrigin`, and `volumeRms` may be read directly.

### 3.4 Raw phase access

Raw phase fields may be read directly only by:

- Selector functions inside `assistant.store.ts`
- `services/assistantRuntime.service.ts`

All other code uses selectors.

---

## 4. Assistant Runtime Verbs

The assistant runtime exposes the following fixed user-facing operations:

```text
submitPrompt
cancelRun

startDictation
cancelDictation
stopDictation
sendDictation

startLiveTalk
pauseLiveTalk
resumeLiveTalk
stopLiveTalk

speakMessage
stopSpeaking

editAndResubmitPrompt
```

These verbs are the single entry points for assistant behavior.

Do not create parallel implementations of these operations elsewhere.

### 4.1 Runtime owns state transitions

Only:

```text
services/assistantRuntime.service.ts
```

may write:

```text
llmPhase
sttPhase
ttsPhase
chatMode
liveTalkPhase
```

Hooks and components call runtime verbs. They do not construct assistant state transitions.

### 4.2 Editing and resubmission

`editAndResubmitPrompt` is the high-level operation for editing a historical user message.

It is responsible for the complete operation:

1. Identify the message being edited.
2. Remove that message and every later message from the current conversation.
3. Update persistent conversation storage.
4. Update the in-memory chat state.
5. Submit the edited text as a new prompt.
6. Rebuild the resulting assistant response from the truncated history.

The UI must not manually perform these steps.

---

## 5. Providers

### 5.1 Provider-agnostic runtime

The runtime calls provider contracts such as:

```text
LlmProvider.generate()
SttProvider.startListening()
TtsProvider.speak()
```

The runtime must not contain provider-specific routing logic.

### 5.2 Provider selection

Provider selection belongs to the provider registry.

For LLMs:

```text
services/providers/llm/index.ts
```

through:

```text
pickLlmProvider(modelId)
```

The same pattern applies to STT and TTS when multiple implementations exist.

### 5.3 Provider isolation

Adding or replacing a provider must not require changes to assistant orchestration.

Provider implementations satisfy the existing provider contract.

---

## 6. Errors and Cancellation

### 6.1 Async operations handle their own failures

Every async runtime verb must handle failures internally.

On failure:

- Set the relevant error state.
- Store a human-readable error.
- Return the affected domain to a safe resting state.

UI event handlers must not depend on catching runtime failures.

### 6.2 Run correlation

Every prompt submission and Live Talk turn receives a unique:

```text
assistantRunId
```

Asynchronous callbacks must verify that their run ID still matches the active run before changing runtime state.

Stale callbacks are ignored.

### 6.3 Native correlation

Native requests use:

```text
requestId
```

Native asynchronous events must carry the request ID needed to correlate them with the originating request.

### 6.4 Cancellation must be real

Cancellation must stop the underlying operation where the provider/native implementation supports cancellation.

Suppressing a callback without stopping the work is not sufficient.

---

## 7. Persistence

| Store                | Persistence                              |
| -------------------- | ---------------------------------------- |
| `assistant.store.ts` | Never                                    |
| `chat.store.ts`      | SQLite-backed conversation state         |
| `model.store.ts`     | Persistent model selection               |
| `settings.store.ts`  | Persistent settings                      |
| `voice.store.ts`     | Persistent selected voice models         |
| `wakeword.store.ts`  | Not persisted; derived from native state |

Every Zustand `persist()` usage must specify an explicit `partialize`.

Never persist an entire store merely for convenience.

---

## 8. Data Flow

The normal application flow is:

```text
Component
   ↓
Hook
   ↓
Assistant Runtime
   ↓
Provider / Domain Service
   ↓
Native Module (when required)
   ↓
Result / Event
   ↓
Runtime / Store
   ↓
Selector
   ↓
Component
```

### Exception

`draftText` may be updated directly while the user is typing.

Typing is plain UI data, not assistant orchestration.

---

## 9. Kotlin Contract

### 9.1 Native API contract

`KrithaModule.kt` must document every JS-facing native function and event, including:

- JS-facing signature
- Purpose
- Relevant request/event data

Keep this contract synchronized with the exposed module API.

### 9.2 Kotlin receives formed requests

For local LLM execution, Kotlin receives an already-formed message/request.

Kotlin may translate the request into the underlying SDK representation.

Kotlin must not decide:

- Which messages belong in context
- Which history to retain
- Which system prompt to use
- Which provider/model should be selected

### 9.3 Native events require request IDs

Every asynchronous or streaming native event must include the originating `requestId`.

### 9.4 Long-running native operations are cancellable

Any long-running native operation must have a cancellation path associated with its request.

---

## 10. Stub Rules

### 10.1 Stubs are explicit

Temporary implementations must contain:

```text
// STUB:
```

and clearly state what real behavior they represent.

### 10.2 Stubs preserve external behavior

A stub must still maintain the expected runtime state transitions.

The rest of the application should observe the same contract regardless of whether the implementation is currently stubbed or real.

### 10.3 Stubs never fabricate believable content

A stub must not invent plausible assistant, transcription, or other runtime data.

For example, an STT stub without real audio input returns an empty transcript.

---

## 11. Code Editing Rules

Every change to the codebase must:

- Follow this document and `CONVENTIONS.md`.
- Inspect the existing implementation before editing.
- Preserve unrelated existing behavior.
- Change ownership only where the architecture requires it.
- Reuse existing stores, services, providers, selectors, and components where appropriate.
- Keep each responsibility in its owning layer.
- Update all affected call sites when an existing API changes.
- Remove dead code when it is genuinely superseded.
- Avoid duplicate implementations or parallel runtime paths.
- Avoid speculative abstractions and unrelated cleanup.
- Never bypass an architectural boundary simply to make an implementation easier.
- Never silently weaken an existing rule.
- Review the final diff for scope creep, stale references, and architectural violations.
- Report only verification that was actually performed.

---

## 12. Design System & Theming

### 12.1 Always prefer design tokens from `theme/index.ts`

UI components and styles must use tokens and constants defined in:

```text
src/theme/index.ts (imported via `@/theme`)
```

Do not use arbitrary magic numbers, hardcoded hex/rgba color codes, or inline random dimension values across UI files.

### 12.2 Token categories to use

- **Colors**: `Colors.<token>` (e.g. `Colors.bgSurface`, `Colors.textPrimary`, `Colors.accentBlue`, `Colors.borderSubtle`, etc.)
- **Typography & Font Sizes**: `Typography.<size>` (e.g. `Typography.sizeBase`, `Typography.sizeSm`, `Typography.sizeLg`, etc.)
- **Icon Sizes**: `IconSizes.<size>` (e.g. `IconSizes.sm`, `IconSizes.md`, `IconSizes.lg`, etc.)
- **Border Radii**: `Radius.<size>` (e.g. `Radius.sm`, `Radius.base`, `Radius.xl`, `Radius.full`, etc.)

If a new token or variant is required, add it to `src/theme/index.ts` first rather than defining one-off hardcoded values in component style definitions.
