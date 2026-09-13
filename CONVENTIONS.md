# Kritha — File & Folder Conventions

Status: **Binding**. Pairs with `RULES.md`. This file is about naming and
location; `RULES.md` is about ownership and behavior.

---

## 1. Target `src/` layout

This is the destination after all phases in this plan are complete —
treat it as the target, not the starting point. `phases/PHASE_0_*` moves
the repo toward it.

src/
├── app/ (unchanged — expo-router screens)
├── components/
│ └── chat/
│ ├── ui/ PascalCase .tsx
│ ├── modals/ PascalCase .tsx
│ └── views/ PascalCase .tsx
├── constants/
│ ├── canonicalStates.ts NEW — Phase 1
│ ├── models.ts
│ ├── storageKeys.ts renamed from storage-keys.ts
│ └── index.ts
├── database/ (unchanged — already conforms, see §2)
├── hooks/
│ ├── useAssistantKeyboard.ts
│ ├── useAssistantSession.ts
│ ├── useChatInput.ts
│ ├── useChatSession.ts
│ ├── useConversationContext.ts
│ ├── usePermissionsChecklist.ts
│ ├── useSidebar.ts
│ ├── useSpeaker.ts
│ ├── useWakeword.ts
│ └── index.ts
├── services/
│ ├── providers/
│ │ ├── llm/
│ │ │ ├── types.ts
│ │ │ ├── cloud.provider.ts
│ │ │ ├── local.provider.ts
│ │ │ └── index.ts
│ │ ├── stt/
│ │ │ ├── types.ts
│ │ │ ├── stub.provider.ts
│ │ │ └── index.ts
│ │ ├── tts/
│ │ │ ├── types.ts
│ │ │ ├── stub.provider.ts
│ │ │ └── index.ts
│ │ └── index.ts
│ ├── app.service.ts
│ ├── assistantRuntime.service.ts NEW — Phase 4
│ ├── chat.service.ts
│ ├── conversation.service.ts
│ ├── model.service.ts
│ ├── permissions.service.ts
│ ├── settings.service.ts
│ └── index.ts
├── stores/ renamed from store/
│ ├── assistant.store.ts NEW — Phase 1, replaces assistantSessionStore.ts + inputStore.ts
│ ├── chat.store.ts renamed from chatStore.ts
│ ├── model.store.ts renamed from modelStore.ts
│ ├── settings.store.ts renamed from settingsStore.ts
│ ├── voice.store.ts renamed from voiceStore.ts, trimmed in Phase 2
│ ├── wakeword.store.ts renamed from wakewordStore.ts
│ └── index.ts
├── theme/ (unchanged)
├── types/ (unchanged, camelCase filenames; types/input.ts removed in Phase 2)
└── utils/ (unchanged, camelCase filenames)


## 2. Naming rules by kind

| Kind | File name pattern | Example | Notes |
|---|---|---|---|
| Zustand store | `<domain>.store.ts` | `assistant.store.ts` | The exported hook stays `useXStore` (e.g. `useAssistantStore`) regardless of file name — only the file needs the suffix. |
| Service | `<domain>.service.ts` | `chat.service.ts` | Exported objects/functions can be named freely (e.g. `ChatSessionService`); only the file needs the suffix. |
| Provider | `<variant>.provider.ts` | `cloud.provider.ts` | Only used inside `services/providers/<capability>/`. Never at the top level of `services/`. |
| Hook | `use<Name>.ts` | `useChatInput.ts` | camelCase, always starts with `use`, matches the exported hook name exactly. |
| Component | `<Name>.tsx` | `ChatComposer.tsx` | PascalCase, matches the exported component name exactly. |
| Constant module | `<name>.ts` | `canonicalStates.ts` | camelCase, no suffix. |
| Type-only module | `<name>.ts` | `chat.ts` | camelCase, no suffix — unless it lives inside a provider folder (`types.ts`), where the folder name already disambiguates. |
| Single-class utility module | `<Name>.ts` | `Database.ts`, `ChatRepository.ts` | PascalCase — this is the pre-existing `database/` convention, kept as-is and not touched by this plan. |
| Plain util function module | `<name>.ts` | `stubAction.ts` | camelCase. |

## 3. The subfolder threshold rule

**One file of a kind → flat. Two or more files of the same kind →
subfolder.**

- `services/chat.service.ts` stays flat — there's only one chat-domain
  service file.
- `services/providers/llm/` is a subfolder because it holds `types.ts`,
  `cloud.provider.ts`, `local.provider.ts`, `index.ts` — four related
  files.
- Don't pre-create subfolders "just in case." Wait until the second file
  of that kind actually exists, then move both into a new subfolder in
  the same change.

## 4. Barrels (`index.ts`)

Every folder under `services/`, `stores/`, `hooks/`, `utils/`, and every
provider subfolder gets an `index.ts` re-exporting its public surface.

- `services/providers/llm/index.ts` exports the `LlmProvider`/`LlmMessage`
  types and `pickLlmProvider`. It does not blindly re-export
  `cloud.provider.ts`'s and `local.provider.ts`'s internals — only what
  outside code actually needs.
- `services/providers/index.ts` re-exports from `llm/`, `stt/`, `tts/`.
- `services/index.ts` re-exports the top-level `*.service.ts` files and
  `export * from './providers'`.

**Consumers outside a folder import from that folder's barrel**
(`@/services`, `@/stores`, `@/hooks`, ...). Deep imports are only allowed
in one situation, and it's a hard rule, not a style preference:

**No file may import its own folder's barrel.** A file inside
`services/` (including `services/assistantRuntime.service.ts`) must
import its sibling `services/*.service.ts` files by direct relative path
(`import { ChatSessionService } from './chat.service';`), never via
`import { ChatSessionService } from '@/services';`. The same applies one
level down: a file inside `services/providers/llm/` must import
`services/settings.service.ts` via `@/services/settings.service`, not via
`@/services`.

Why this is a hard rule and not a suggestion: `services/index.ts`
re-exports `assistantRuntime.service.ts`, and `assistantRuntime.service.ts`
needs `ChatSessionService`, `buildConversationContext`, and the provider
registry. If it pulled any of those through the `@/services` barrel, you'd
get `services/index.ts` → `assistantRuntime.service.ts` → `@/services`
(== `services/index.ts` again) — a circular import that silently produces
`undefined` exports at runtime. `services/providers/llm/cloud.provider.ts`
needing `settingsService` has the identical trap one level down. Both are
called out explicitly in `phases/PHASE_3_*` and `phases/PHASE_4_*` — don't
"clean up" those imports to go through the barrel later.

## 5. Path aliases

Locate the module resolver config — check `tsconfig.json`
(`compilerOptions.paths`), `babel.config.js` (`module-resolver` plugin),
and `metro.config.js`, in that order; this project may define aliases in
more than one of these, so keep them in sync — and update:

- `@/store` → `@/stores` (folder renamed in Phase 0)

All other aliases (`@/services`, `@/hooks`, `@/components`, `@/constants`,
`@/types`, `@/utils`, `@/database`, `@/theme`) stay as they are.

## 6. Required file header banner

The following files must start with a comment block in this exact shape:

```ts
/**
 * PURPOSE:  <one line, what this file is for>
 * OWNS:     <one line, what state/behavior this file is the source of truth for>
 * NOT-OWNS: <one line, what a reader might expect here but must look elsewhere for>
 * SEE ALSO: <RULES.md section reference, e.g. "RULES.md §4">
 */
```

Required on: `stores/assistant.store.ts`, every file in
`services/providers/**`, `services/assistantRuntime.service.ts`, and the
Kotlin files touched in the native-bridge phase (`LocalLlmExecutor.kt`,
and the contract block in `KrithaModule.kt`). Optional elsewhere but
encouraged.

## 7. Kotlin naming conventions

| Suffix | Meaning | Example |
|---|---|---|
| `*Manager` | Owns the lifecycle of a native resource (create/reuse/release); no business logic | `LiteRTEngineManager` |
| `*Executor` | Stateless: takes a fully-formed command, does the thing, returns a result | `AssistantToolExecutor`, `LocalLlmExecutor` |
| `*Module` | The single Expo Modules entry point exposed to JS | `KrithaModule` |
| `*Native` | Thin JNI/native-library bridge; no Kotlin-side logic beyond marshaling | `WakeWordNative` |

**Forbidden Kotlin class/file name fragments anywhere in the Android
source tree:** `Orchestrator`, `AssistantRuntime`, `ConversationManager`,
`AssistantSessionManager`. Android's own `VoiceInteractionSession` /
`VoiceInteractionSessionService` are legitimate platform SDK types and
are not affected — the ban is on Kritha inventing its own
assistant-session/orchestration abstractions in Kotlin (see RULES.md
§1.3).

## 8. Formatting

- Prefer named exports over default exports for everything except Expo
  Router screen files (`app/*.tsx`), which Expo Router requires to be
  default exports.
- Keep comments short and plain — a one-line `//` comment beats a
  decorative banner. The required header banner in §6 is the one
  exception, and it's fixed-format for a reason (it's meant to be
  grep-able).