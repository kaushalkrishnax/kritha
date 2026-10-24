# Kritha agent guide

## Comment policy

- No obvious or common-sense comments; code should be self-explanatory.
- Keep only non-obvious "why" notes; drop restatements of what the code does.
- Prefer single-line comments; collapse multi-line blocks unless the detail is essential.
- No changelog-style, AI-slop, or speculative commentary.

## Build commands — always use `package.json` scripts

Never run raw `flutter build` commands directly; use the scripts in `package.json`:

- `npm run build:android` — signed release APKs (arm64-v8a, x86_64) under `dist/android/`
- `npm run build:aab` — signed release AAB (universal) under `dist/android/`
- `npm run build:app` — signed arm64 IPA under `dist/ios/`
- `npm run build:ios` — unsigned local arm64 iOS device `.app` under `dist/ios/`
- `npm run build:macos` — signed arm64 and x86_64 macOS `.app` bundles under `dist/macos/`
- `npm run build:windows` — Windows x64 release (Windows host only)
- `npm run bump:beta`, `npm run bump:release` — version bump + tag

Only `--no-codesign` is acceptable as an extra flag (iOS/local unsigned builds). Do **not** add `--no-tree-shake-icons` or any other raw `flutter build` flags.

## References

- `README.md` — project overview, release artifact table, build scripts, platform targets, design system pointer
- `docs/DESIGN_CONVENTIONS.md` — tokens, typography, colour, spacing, responsive rules, change checklist
- `docs/BUTTONS.md` — every interactive control, states, sizing, decision tree
- `docs/UI_PATTERNS.md` — shell, header, sidebar, composer, dictation, Live Talk, overlays, pattern checklist
- `docs/COMPONENTS.md` — component inventory and remaining stubs / hand-off notes
- `package.json` — authoritative build commands and versions
- `pubspec.yaml` — pinned Flutter dependencies
- `lib/core/theme.dart` — single source of truth: colours, type, radii, spacing, dimensions, motion, `KrithaIcon` wrapper

## Key implementation notes

- **No WebRTC** anywhere in this project; do not treat it as a real feature.
- **No dynamic delivery**: the `GloballyDynamicBuildConfig.kt`, `RuntimePackBridge.kt`, `android/feature_sherpa_litertlm/`, `dynamicFeatures`, `globallyDynamicServerUrl` and all dynamic-feature wiring were removed. Wake-word inference runs in the base APK foreground service (`lib/services/wake_word_bridge.dart`, `android/app/src/main/kotlin/com/kritha/app/wakeword/`).
- **Plugins sidebar**: `lib/features/chat/widgets/chat_sidebar.dart` row is `Plugins`; runtime-delivery-only UI was removed.
- **Edge Impulse SDK**: kept as the committed zip under `edge-impulse-exports/kritha-cpp-android-v5-impulse-#1.zip`; extracted at CMake configure time from `android/app/src/main/cpp/CMakeLists.txt`. Do not commit raw extracted SDK files.
- **iOS unsigned builds**: macOS/iOS Release configs use `CODE_SIGN_STYLE = Manual` with `CODE_SIGN_IDENTITY = "-"` and empty `DEVELOPMENT_TEAM` for local unsigned builds (see `macos/Runner/Configs/Signing.xcconfig`). Distribution still requires a valid signing identity — do not claim a signed build without one.
- **litertlm**: local patched copy at `packages/litertlm` with `-std=c++17` in `hook/build.dart`; referenced via `path:` in `pubspec.yaml`. Do not edit `.pub-cache` directly.
- **Flutter version**: 3.47.7 / Dart 3.13.5 (verified against).
