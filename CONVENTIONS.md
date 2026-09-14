# Kritha — File & Folder Conventions

**Status: Binding**

This document defines permanent naming, location, import, and structural conventions.

`RULES.md` defines ownership and behavior.

---

## 1. Source Layout

```text
src/
├── app/
├── components/chat/
│   ├── ui/
│   ├── modals/
│   └── views/
├── constants/
├── database/
├── hooks/
├── services/
│   └── providers/
│       ├── llm/
│       ├── stt/
│       └── tts/
├── stores/
├── theme/
├── types/
└── utils/
```

Use existing directories according to responsibility. Do not create speculative directories.

---

## 2. Naming Rules

| Kind           | Pattern                 | Example              |
| -------------- | ----------------------- | -------------------- |
| Store          | `<domain>.store.ts`     | `assistant.store.ts` |
| Service        | `<domain>.service.ts`   | `chat.service.ts`    |
| Provider       | `<variant>.provider.ts` | `cloud.provider.ts`  |
| Hook           | `use<Name>.ts`          | `useChatInput.ts`    |
| Component      | `<Name>.tsx`            | `ChatInput.tsx`      |
| Constant       | `<name>.ts`             | `canonicalStates.ts` |
| Type module    | `<name>.ts`             | `chat.ts`            |
| Database class | `<Name>.ts`             | `Database.ts`        |
| Utility        | `<name>.ts`             | `stubAction.ts`      |

Filenames should describe the responsibility of the module.

---

## 3. Subfolder Rule

**One related file → flat.
Two or more related files → subfolder.**

Do not create folders in anticipation of future files.

---

## 4. Barrels

Use `index.ts` for:

```text
services/
stores/
hooks/
utils/
services/providers/<capability>/
```

Consumers outside a directory normally import from its barrel:

```ts
import { ChatSessionService } from '@/services';
import { useAssistantStore } from '@/stores';
```

**No self-barrel imports.**

A file must not import its own directory's barrel.

Inside `services/`:

```ts
import { ChatSessionService } from './chat.service';
```

Inside provider directories, import external services directly:

```ts
import { settingsService } from '@/services/settings.service';
```

Do not bypass this rule for stylistic consistency.

---

## 5. Path Aliases

Keep aliases synchronized across:

```text
tsconfig.json
babel.config.js
metro.config.js
```

Canonical aliases:

```text
@/components
@/constants
@/database
@/hooks
@/services
@/stores
@/theme
@/types
@/utils
```

Use aliases for cross-directory imports and direct relative imports for required sibling imports.

---

## 6. Components

Components use PascalCase and the filename must match the exported component:

```text
ChatInput.tsx
ChatMessages.tsx
SettingsModal.tsx
```

Place components according to UI responsibility:

```text
components/chat/ui/
components/chat/modals/
components/chat/views/
```

Do not place services, stores, or domain logic in component directories.

---

## 7. Hooks

Hooks use:

```text
use<Name>.ts
```

The filename must match the exported hook name.

Examples:

```text
useChatInput.ts
useSpeaker.ts
useSidebar.ts
```

---

## 8. Services

Services use:

```text
<domain>.service.ts
```

Examples:

```text
chat.service.ts
conversation.service.ts
model.service.ts
permissions.service.ts
assistantRuntime.service.ts
```

Exported functions or objects may use any appropriate name.

---

## 9. Stores

Stores use:

```text
<domain>.store.ts
```

Examples:

```text
assistant.store.ts
chat.store.ts
model.store.ts
settings.store.ts
```

The exported Zustand hook follows:

```text
use<Domain>Store
```

Example:

```text
assistant.store.ts → useAssistantStore
```

---

## 10. Providers

Providers are grouped by capability:

```text
services/providers/
├── llm/
├── stt/
└── tts/
```

Implementations use:

```text
<variant>.provider.ts
```

Examples:

```text
cloud.provider.ts
local.provider.ts
stub.provider.ts
```

Provider implementations stay inside their capability directory.

---

## 11. Constants and Types

Constants use camelCase filenames:

```text
canonicalStates.ts
models.ts
storageKeys.ts
```

Type modules use camelCase:

```text
chat.ts
models.ts
permissions.ts
```

Provider-specific types may use `types.ts`.

Keep shared vocabulary defined in one canonical location.

---

## 12. Kotlin Naming

| Suffix      | Meaning                         | Example               |
| ----------- | ------------------------------- | --------------------- |
| `*Manager`  | Native resource lifecycle       | `LiteRTEngineManager` |
| `*Executor` | Executes a fully formed request | `LocalLlmExecutor`    |
| `*Module`   | Expo Modules entry point        | `KrithaModule`        |
| `*Native`   | Thin native/library bridge      | `WakeWordNative`      |

Do not introduce Kritha classes named:

```text
*Orchestrator
*AssistantRuntime
*ConversationManager
*AssistantSessionManager
```

Platform SDK classes with similar names are unaffected.

---

## 13. Exports

Prefer named exports.

Default exports are reserved for framework-required cases such as Expo Router screens.

---

## 14. Comments

Keep comments short and explain why when necessary.

```ts
// Direct import avoids the services barrel circular dependency.
```

Avoid comments that merely restate the code.

Required architectural headers defined by `RULES.md` remain mandatory.

---

## 15. New Files and Exceptions

Before adding a file, determine:

- its kind and correct directory,
- whether the subfolder rule applies,
- whether its public API belongs in a barrel,
- whether it introduces a new convention.

Do not introduce one-off naming or structural patterns.

If a genuinely new convention is required, update this document explicitly.

---

## 16. Relationship to RULES.md

```text
CONVENTIONS.md
→ naming
→ locations
→ folders
→ imports
→ exports

RULES.md
→ ownership
→ behavior
→ boundaries
→ runtime architecture
```

All code changes must satisfy both documents.
