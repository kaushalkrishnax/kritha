---
name: globally-dynamic-runtime-delivery
description: Project-specific Kritha guidance for optional Android runtime delivery using dynamic feature modules and GloballyDynamic. Covers module boundaries, RuntimeManager, provider discovery, self-hosted delivery, future store backends, lifecycle, signing, versioning, and tests.
---

# Kritha — GloballyDynamic Runtime Delivery Skill

## Purpose

Project-specific implementation knowledge for optional Android runtime delivery in Kritha.

This skill defines the architecture, module boundaries, delivery abstraction, installation lifecycle, provider discovery, self-hosted rollout, future store integration, and implementation constraints. Agents should treat it as the source of truth for runtime delivery work and should not re-design this system unless the repository explicitly contradicts it.

---

## 1. Target Architecture

Kritha ships a **runtime-free base app**. Runtime binaries are not bundled into the base application.

The base app contains:

- React Native/UI and assistant runtime
- Cloud AI integration
- Runtime contracts and runtime manager
- GloballyDynamic integration/adapter
- Android system speech fallback (`SpeechRecognizer`, Android `TextToSpeech`)
- Small built-in wake-word implementation
- Model-management infrastructure
- No LiteRT, LiteRT-LM, or ONNX Runtime native runtime binaries

Optional runtime modules are installed on demand:

| Runtime ID | Dynamic feature | Responsibility |
|---|---|---|
| `LITERT` | `feature-litert` | Generic LiteRT execution; LiteRT-backed ASR/TTS/vision/other tasks |
| `LITERT_LM` | `feature-litertlm` | LiteRT-LM local LLM execution |
| `ONNX` | `feature-onnx` | ONNX Runtime execution and ONNX-backed ASR/TTS/other models |

The three runtimes are visible user-facing choices. Installation state must be represented explicitly in the UI.

### Hard boundary

`app` knows **what** a runtime can do and **whether** it is available.

A feature module knows **how** its runtime works.

`app` must not directly import classes from `feature-litert`, `feature-litertlm`, or `feature-onnx`.

Feature modules may depend on `app`.

```text
app
 ├── runtime contracts
 ├── RuntimeManager
 └── GloballyDynamic delivery adapter
        │
        ├── feature-litert       → LiteRT implementation
        ├── feature-litertlm     → LiteRT-LM implementation
        └── feature-onnx         → ONNX Runtime implementation
```

This dependency direction is deliberate and must not be inverted. Android's dynamic-feature model likewise makes feature modules depend on the base app while the base declares its dynamic features. citeturn170751search4

---

## 2. Runtime vs Model Separation

A runtime feature is **execution infrastructure**, not a model package.

### Dynamic feature contains

- Runtime `.so` files / native binaries
- Runtime-specific Java/Kotlin integration
- Runtime-specific adapters
- Runtime-specific resource/configuration files
- Runtime-specific initialization and cleanup code

### Model manager contains

- Model weights
- Tokenizers / vocabularies when treated as model assets
- Model manifests and metadata
- Model download/update/delete lifecycle
- Model selection/versioning

Do not put large model weights inside dynamic feature APKs unless a future explicit decision changes this architecture.

Correct flow:

```text
install runtime feature
        ↓
select/download model separately
        ↓
load model through runtime provider
        ↓
execute task
```

---

## 3. Base Runtime Contract

The base module should expose a narrow runtime API. Keep it task-oriented and runtime-agnostic.

Recommended shape:

```kotlin
enum class RuntimeId {
    LITERT,
    LITERT_LM,
    ONNX,
}

interface RuntimeProvider {
    val id: RuntimeId
    fun isAvailable(): Boolean

    fun asr(): AsrProvider? = null
    fun tts(): TtsProvider? = null
    fun llm(): LlmProvider? = null
    fun image(): ImageProvider? = null
}
```

Use the project's existing speech/model contracts where they already exist. Do not duplicate them merely to support dynamic delivery.

If an existing abstraction is already runtime-neutral, reuse it and make the feature implementation conform to it.

### Provider implementation names

Use:

- `LiteRTRuntimeProvider`
- `LiteRTLLMRuntimeProvider`
- `OnnxRuntimeProvider`

Do not expose runtime-specific engine classes through the base contract.

---

## 4. RuntimeManager Responsibilities

`RuntimeManager` lives in `app`.

It is the only orchestration point the assistant/UI should need for runtime delivery.

It owns:

1. Runtime catalog (`RuntimeId → module name/capabilities`)
2. Installed-state checks
3. Runtime installation requests
4. Installation progress/state mapping
5. Provider discovery after installation
6. Provider caching
7. Runtime unload/release coordination
8. Error translation into app-level errors
9. Delivery backend selection through an abstraction

It must **not** contain LiteRT/ONNX/LiteRT-LM implementation logic.

Recommended conceptual API:

```kotlin
interface RuntimeManager {
    fun isInstalled(runtime: RuntimeId): Boolean
    suspend fun ensureInstalled(runtime: RuntimeId): RuntimeProvider
    fun provider(runtime: RuntimeId): RuntimeProvider?
    suspend fun release(runtime: RuntimeId)
}
```

Exact signatures may follow the project's coroutine/event conventions; the architectural responsibility must remain the same.

---

## 5. Delivery Abstraction

Do not hard-code GloballyDynamic calls throughout the application.

Create a small base-side abstraction such as:

```kotlin
interface DynamicDeliveryClient {
    fun isInstalled(moduleName: String): Boolean
    suspend fun install(moduleName: String): InstallResult
    fun observe(moduleName: String): Flow<InstallState>
}
```

`GloballyDynamicDeliveryClient` is the current Android implementation.

This gives Kritha:

```text
RuntimeManager
      ↓
DynamicDeliveryClient
      ↓
GloballyDynamic
      ↓
Play / self-hosted / other supported delivery backend
```

The rest of the app must not know whether the current delivery source is self-hosted or a store.

---

## 6. GloballyDynamic Role

GloballyDynamic is the **delivery abstraction**, not the runtime system and not the model manager.

Use it to obtain/install Android dynamic feature splits through a unified client API across supported distribution environments. The project describes support for Google Play and Huawei delivery, plus server-backed delivery for environments such as Samsung, Amazon, Firebase/internal builds, local development, and devices without a native dynamic-delivery store. citeturn528027view0

Do not:

- call GloballyDynamic from runtime adapters
- make a runtime provider responsible for downloading itself
- treat GloballyDynamic as a model downloader
- embed store-specific logic in `RuntimeManager`

---

## 7. Feature Module Structure

Use three independent Android dynamic feature modules.

```text
android/
├── app/
│   └── src/main/java/.../runtime/
│       ├── RuntimeId.kt
│       ├── RuntimeProvider.kt
│       ├── RuntimeManager.kt
│       ├── DynamicDeliveryClient.kt
│       ├── GloballyDynamicDeliveryClient.kt
│       └── RuntimeCatalog.kt
│
├── feature-litert/
│   └── src/main/java/.../litert/
│       ├── LiteRTRuntimeProvider.kt
│       ├── LiteRTRuntime.kt
│       ├── LiteRTSession.kt
│       ├── LiteRTTypes.kt
│       ├── LiteRTApi.kt
│       └── speech/...
│
├── feature-litertlm/
│   └── src/main/java/.../litertlm/
│       ├── LiteRTLLMRuntimeProvider.kt
│       └── LiteRTLLM.kt
│
└── feature-onnx/
    └── src/main/java/.../onnx/
        ├── OnnxRuntimeProvider.kt
        └── ...
```

The exact Java/Kotlin package can preserve the existing package where practical. Moving code is preferred over rewriting working runtime internals.

### Existing LiteRT migration

The current `litert/` implementation is already a working generic LiteRT runtime. Treat the migration as a module-boundary refactor first:

- move the generic LiteRT runtime implementation into `feature-litert`
- move LiteRT speech adapters there
- move LiteRT TTS implementations there
- keep existing execution behavior intact
- introduce only the provider boundary required for dynamic loading

Do not rewrite `LiteRTRuntime` merely because it moved modules.

### LiteRT-LM migration

Move `LiteRTLLM.kt` and all LiteRT-LM-specific integration into `feature-litertlm`.

The base module must not import `com.google.ai.edge.litertlm.*`.

### ONNX

`feature-onnx` starts as a sibling runtime feature and should follow the same provider contract. Do not add ONNX dependencies to `app`.

---

## 8. Gradle Dependency Direction

The base app declares its dynamic feature modules using `android.dynamicFeatures`.

Conceptually:

```kotlin
android {
    dynamicFeatures += setOf(
        ":feature-litert",
        ":feature-litertlm",
        ":feature-onnx",
    )
}
```

Each feature module uses the dynamic-feature plugin and depends on the base app:

```kotlin
plugins {
    id("com.android.dynamic-feature")
}

dependencies {
    implementation(project(":app"))
}
```

Do **not** add this to `app`:

```kotlin
implementation(project(":feature-litert"))
```

That defeats the intended module boundary and can cause the runtime code to become part of the base dependency graph.

Android's dynamic feature documentation explicitly establishes this relationship: base declares dynamic features; feature declares `implementation(project(":app"))`. citeturn170751search4

Feature `minSdk` must remain compatible with the base. Base-owned signing/application configuration stays in `app`; do not independently turn a feature into an application module. citeturn170751search0turn170751search2

---

## 9. Module Names Are API

These strings are delivery identifiers and must remain stable:

```text
feature-litert
feature-litertlm
feature-onnx
```

Runtime catalog:

```kotlin
RuntimeId.LITERT     → "feature-litert"
RuntimeId.LITERT_LM  → "feature-litertlm"
RuntimeId.ONNX       → "feature-onnx"
```

Do not use arbitrary display names as module identifiers.

If a module is renamed, update all of:

- Gradle module name
- `dynamicFeatures`
- feature delivery metadata
- runtime catalog
- GloballyDynamic install requests
- ServiceLoader/provider registration
- tests
- self-hosted server artifacts

---

## 10. Provider Discovery

The base module cannot statically reference feature implementation classes.

Preferred discovery mechanism: Java `ServiceLoader` after the module is installed.

Each feature registers its provider using:

```text
META-INF/services/<fully-qualified-base-RuntimeProvider-interface>
```

with a line such as:

```text
<fully-qualified-LiteRTRuntimeProvider>
```

Repeat for each feature provider.

Provider discovery sequence:

```text
module installed
      ↓
feature classes become available
      ↓
ServiceLoader.load(RuntimeProvider::class.java)
      ↓
find provider whose id == requested RuntimeId
      ↓
cache provider in RuntimeManager
```

Because provider classes are discovered indirectly, ensure release/R8 configuration preserves them and their public constructors.

Do not make provider discovery the installation mechanism; installation must happen first.

---

## 11. Installation State Machine

Runtime installation must be modeled as a stateful operation, not as a boolean.

Minimum states:

```text
NOT_INSTALLED
CHECKING
INSTALLING
INSTALLED
INITIALIZING
READY
FAILED
CANCELLED
```

User-visible runtime state can be simplified, but internal transitions must preserve enough information to diagnose failures.

Canonical flow:

```text
request(RuntimeId)
    ↓
resolve RuntimeCatalog entry
    ↓
check feature installed
    ├── yes → discover provider → initialize → READY
    └── no  → request dynamic install
                  ↓
             emit progress/events
                  ↓
             installed
                  ↓
             discover provider
                  ↓
             initialize
                  ↓
                 READY
```

If installation fails, do not report the runtime as installed merely because an install session was created.

---

## 12. GloballyDynamic Self-Hosted Flow

Current development/distribution target: **self-hosted delivery**.

The intended path is:

```text
Gradle build
   ↓
AAB containing base + dynamic feature splits
   ↓
GloballyDynamic server pipeline
   ↓
bundle/split processing
   ↓
server exposes feature APK artifacts
   ↓
Kritha app requests module through GloballyDynamic
   ↓
feature split downloaded + installed
   ↓
RuntimeManager discovers provider
```

GloballyDynamic's server-backed mode exists specifically to provide dynamic delivery where the distribution platform does not natively provide Play-style feature delivery and also supports internal/local-development scenarios. citeturn528027view0

### Android-side concept

The self-hosted provider follows the GloballyDynamic API shape used by the project ecosystem:

```kotlin
val manager = GlobalSplitInstallManagerFactory.create(
    context,
    GlobalSplitInstallProvider.SELF_HOSTED,
)

val request = GlobalSplitInstallRequest.newBuilder()
    .addModule("feature-litert")
    .build()

manager.startInstall(request)
```

Use the exact dependency/API version chosen by the repository. Do not invent alternate wrappers when the library already provides this API.

### Server-side rule

Treat the server as a **delivery backend**, not as part of Kritha runtime logic.

The build pipeline must publish the same module identifiers that the client requests.

Every published runtime artifact must be traceable to a specific Kritha app version/build.

---

## 13. Signing and Artifact Integrity

Self-hosted delivery still needs valid Android split artifacts compatible with the installed base application.

Do not bypass Android signing/integrity requirements merely because delivery is self-hosted.

When configuring the GloballyDynamic server/plugin pipeline:

- use the project's real release-signing strategy
- keep secrets out of source control
- avoid copying keystore passwords into Gradle files or checked-in config
- prefer CI/environment-secret injection
- enable signature validation/verification where supported by the chosen GloballyDynamic setup
- make base AAB and feature artifacts version-aligned

Do not introduce a second independent signing authority for runtime splits without explicitly accounting for Android's package/signature requirements.

---

## 14. Future Store Delivery

Self-hosted is an implementation choice for the current stage, not the app architecture.

Future delivery may use another GloballyDynamic backend supported by the distribution platform.

The application-facing path remains:

```text
RuntimeManager
    ↓
DynamicDeliveryClient
    ↓
GloballyDynamic backend
```

Changing from self-hosted to Play-backed delivery should not require changing runtime providers, assistant logic, or model-management code.

Do not build Play-specific assumptions into `RuntimeManager`.

---

## 15. UI Contract

The runtime screen exposes exactly three runtime choices:

```text
LiteRT
LiteRT-LM
ONNX Runtime
```

Each runtime should expose enough state for the UI to distinguish:

```text
Available / Not installed / Installing / Ready / Failed
```

Example conceptual model:

```kotlin
data class RuntimeStatus(
    val id: RuntimeId,
    val installed: Boolean,
    val installing: Boolean,
    val progress: Int?,
    val ready: Boolean,
    val error: String?,
)
```

Do not hide runtime installation behind unrelated assistant actions. The user should be able to see and manage runtime availability explicitly.

Runtime installation is independent from model installation.

---

## 16. Base-App Speech Fallback

The base app intentionally provides speech without shipping a third-party speech runtime:

- ASR fallback → Android `SpeechRecognizer`
- TTS fallback → Android `TextToSpeech`

This means Kritha can remain functional without installing LiteRT/ONNX.

Third-party/model-based speech becomes an optional enhancement provided by runtime features.

Do not move the Android system speech fallback into a runtime feature.

---

## 17. Wake Word

The built-in wake-word implementation is allowed in the base app because it is intentionally small.

Do not treat the wake-word component as one of the three optional model runtimes unless the project architecture is explicitly changed later.

---

## 18. Existing LiteRT Code: Migration Rules

Current generic LiteRT code is runtime-specific and belongs in `feature-litert`:

```text
LiteRTRuntime.kt
LiteRTSession.kt
LiteRTTypes.kt
LiteRTApi.kt
LiteRTRuntimeFacade.kt (replace/split; do not retain cross-runtime coupling)
speech/*
```

The current facade directly instantiates multiple runtime systems. That is not allowed after modularization.

Replace the cross-runtime facade with base-side runtime orchestration:

```text
OLD
LiteRTRuntimeFacade
 ├── LiteRTRuntime
 ├── SpeechRuntime
 ├── Tts
 ├── LiteRTLLM
 └── direct runtime construction

NEW
RuntimeManager
 ├── DynamicDeliveryClient
 ├── RuntimeCatalog
 └── RuntimeProvider(s)
       ├── LiteRTRuntimeProvider
       ├── LiteRTLLMRuntimeProvider
       └── OnnxRuntimeProvider
```

The provider owns construction of its runtime-specific engine(s).

---

## 19. Runtime Initialization

A provider should initialize lazily.

Do not load native runtime libraries at app startup.

Correct:

```text
app startup
    ↓
no runtime loaded
    ↓
user/request needs LiteRT
    ↓
ensureInstalled(LITERT)
    ↓
provider created
    ↓
runtime initialized
```

This preserves the runtime-free base experience and avoids paying runtime initialization cost when unused.

Likewise, release/unload must be possible without terminating the entire app.

---

## 20. Concurrency Rules

`RuntimeManager` must deduplicate concurrent installation requests.

Example:

```text
UI requests LiteRT
assistant requests LiteRT
background model check requests LiteRT
                  ↓
           ONE install session
                  ↓
        all callers await same result
```

Do not start multiple GloballyDynamic installation sessions for the same module simultaneously unless the underlying library explicitly requires it.

Provider initialization should likewise be synchronized so concurrent callers do not create multiple native runtime instances accidentally.

---

## 21. Failure Handling

Translate delivery/runtime failures into project-level errors.

At minimum distinguish:

- feature unavailable for current distribution environment
- network unavailable
- download failed
- installation cancelled
- installation rejected/incompatible
- signature/integrity failure
- provider discovery failure
- runtime initialization failure
- native library load failure
- model unavailable

Do not collapse all of these into `RuntimeException("install failed")`.

A runtime feature being installed does not imply that a compatible model is installed.

---

## 22. Offline Behavior

The app must remain usable with:

```text
no optional runtime installed
```

and should continue to expose base functionality through:

```text
cloud AI
Android SpeechRecognizer
Android TextToSpeech
built-in wake word
```

When a runtime is already installed, normal runtime operation should not require the delivery server.

Only installation/update needs the delivery backend.

---

## 23. Versioning Rules

Runtime compatibility is tied to the base app build.

A runtime split built for an incompatible base application must not be installed or silently reused.

The delivery catalog should therefore be logically keyed by:

```text
applicationId
base app version/build identity
runtime module name
runtime feature version
```

The model manager separately tracks:

```text
model ID
model version
model format
runtime compatibility
```

Do not use model version as runtime feature version.

---

## 24. Release Pipeline

For every release-capable build:

```text
1. Build base + feature modules as one AAB
2. Generate/publish distributable artifacts through the selected delivery pipeline
3. Keep module names stable
4. Ensure feature artifacts match the base version/signing expectations
5. Publish the runtime catalog metadata used by the client, when required
6. Test installation on a fresh base-only install
7. Test already-installed runtime path
8. Test failed/cancelled install path
```

Self-hosted delivery should be treated as a real deployment target, not as an ad-hoc APK copy mechanism.

---

## 25. Testing Matrix

Every runtime feature should have these scenarios:

### Fresh install

```text
base installed
all three runtimes absent
→ app starts successfully
```

### First runtime install

```text
select LiteRT
→ download
→ progress
→ install
→ provider discovery
→ runtime ready
```

### Re-open

```text
LiteRT already installed
→ no download
→ provider available immediately/lazily
```

### Concurrent request

```text
multiple callers request same runtime
→ one installation
→ all callers receive same final state
```

### Failure

```text
server unavailable / cancelled / corrupt / incompatible
→ clear failure state
→ retry remains possible
→ app itself remains usable
```

### Runtime absence

```text
LiteRT unavailable
→ system speech fallback still works
```

### Upgrade

```text
new base app
→ existing runtime is checked for compatibility
→ incompatible runtime is not blindly reused
```

Android's current tooling also supports local simulation of dynamic feature installation using bundletool when testing app bundles, which is useful for verifying on-demand behavior before store delivery. citeturn170751search1

---

## 26. Implementation Order

When implementing this architecture in the current repository, use this sequence:

```text
1. Create base runtime contracts.
2. Create RuntimeCatalog with the three fixed RuntimeId/module-name mappings.
3. Create DynamicDeliveryClient abstraction.
4. Implement GloballyDynamicDeliveryClient.
5. Create :feature-litert as a dynamic feature.
6. Move existing LiteRT implementation into :feature-litert with minimal code changes.
7. Add LiteRTRuntimeProvider + provider registration.
8. Create :feature-litertlm.
9. Move LiteRT-LM implementation there.
10. Add LiteRTLLMRuntimeProvider + provider registration.
11. Create empty :feature-onnx following the same contract.
12. Replace the old all-runtime LiteRTRuntimeFacade with RuntimeManager orchestration.
13. Wire runtime installation/status to the existing JS/native bridge only at the high-level contract boundary.
14. Configure GloballyDynamic self-hosted delivery.
15. Test fresh base-only installation.
16. Test each runtime's first install and subsequent reuse.
17. Add ONNX implementation later without changing the base contract.
```

Avoid performing unrelated refactors during this migration.

---

## 27. Agent Rules

### Always

- Preserve the base/feature dependency direction.
- Keep runtime binaries out of `app`.
- Keep model files out of runtime feature delivery.
- Keep GloballyDynamic behind `DynamicDeliveryClient`.
- Keep the three runtime IDs stable.
- Reuse existing runtime implementation code where possible.
- Make runtime initialization lazy.
- Make installation idempotent and concurrency-safe.
- Preserve an Android system speech fallback.
- Keep provider discovery independent of installation.
- Add/maintain R8 rules for indirectly discovered providers.
- Test the base app with zero optional runtime features installed.

### Never

- `app → implementation(project(":feature-*"))`
- import LiteRT/ONNX/LiteRT-LM runtime classes in base runtime management code
- start native runtime initialization from `Application.onCreate()` just because the feature exists
- download model weights as part of runtime installation
- make a runtime adapter invoke GloballyDynamic directly
- assume an installed runtime means a model is present
- create one giant runtime facade containing all runtime implementations
- rename module IDs casually
- put distribution/store-specific logic into assistant core
- bundle optional runtime `.so` files into the base application “for convenience”

---

## 28. Decision Records

### Why dynamic feature modules?

They allow runtime-specific code/resources/native libraries to be separated from the base app and delivered on demand. Android's feature-module model explicitly supports on-demand features and packages them as dynamic modules. citeturn170751search2turn170751search4

### Why GloballyDynamic?

Kritha needs the application architecture to survive changes in distribution channel. GloballyDynamic supplies a common client surface while its underlying delivery path can vary between Play-style delivery and server-backed delivery environments. citeturn528027view0

### Why self-hosted first?

Kritha currently needs a distribution path that does not depend on having a Play Store developer setup. Self-hosted GloballyDynamic provides the delivery path while preserving the same application-facing runtime manager abstraction.

### Why keep models separate?

Runtime binaries are infrastructure; model weights are user-selectable data with their own lifecycle, size, compatibility, and updates. Separating them prevents every model change from becoming a feature-module release.

---

## 29. Reference Architecture

```text
                         KRITHA BASE APP
┌──────────────────────────────────────────────────────────────┐
│ React Native / Assistant Core                                │
│ Cloud AI                                                     │
│ Android SpeechRecognizer / TextToSpeech                      │
│ Wake Word                                                     │
│                                                              │
│ RuntimeManager                                               │
│   ├── RuntimeCatalog                                         │
│   ├── DynamicDeliveryClient                                  │
│   │      └── GloballyDynamicDeliveryClient                   │
│   └── RuntimeProvider discovery/cache                        │
└───────────────────────────────┬──────────────────────────────┘
                                │
              on-demand feature installation
                                │
        ┌───────────────────────┼────────────────────────┐
        │                       │                        │
        ▼                       ▼                        ▼
┌─────────────────┐   ┌────────────────────┐   ┌─────────────────┐
│ feature-litert  │   │ feature-litertlm   │   │ feature-onnx    │
│                 │   │                    │   │                 │
│ LiteRT runtime  │   │ LiteRT-LM runtime  │   │ ONNX runtime    │
│ LiteRT adapters │   │ LLM provider       │   │ ONNX adapters   │
│ native libs     │   │ native libs        │   │ native libs     │
└────────┬────────┘   └─────────┬──────────┘   └────────┬────────┘
         │                      │                       │
         └─────────────── RuntimeProvider ─────────────┘
                                │
                                ▼
                        Runtime-specific execution
                                │
                                ▼
                       MODEL MANAGER / MODEL FILES
```

---

## 30. External References

Use these when an implementation detail is uncertain; prefer the repository's pinned dependency versions and existing code over copying examples from another version.

- Android Dynamic Feature Modules: https://developer.android.com/guide/play/feature-delivery
- Android on-demand delivery: https://developer.android.com/guide/playcore/feature-delivery/on-demand
- GloballyDynamic project: https://github.com/jeppeman/GloballyDynamic
- GloballyDynamic documentation: https://globallydynamic.io/

The GloballyDynamic repository is a third-party project; do not treat its API as an Android platform API. Verify the exact version/API surface used by this repository before adding or upgrading dependencies. The project README documents its supported delivery environments and unified client approach. citeturn528027view0

---

## Final Invariant

The one rule that should survive every future implementation change:

```text
KRITHA BASE APP = assistant + contracts + delivery orchestration
RUNTIME FEATURE  = runtime implementation + native binaries
MODEL MANAGER    = model files + model lifecycle
DELIVERY LAYER   = GloballyDynamic/backend selection
```

An agent implementing a new runtime, changing delivery providers, or modifying installation behavior should preserve these four boundaries.
