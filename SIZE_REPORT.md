# Kritha stack — ARM64 release APK size report

> Historical measurement. The current Android build supports both `arm64-v8a`
> and `x86_64`; re-run the command below for a current per-ABI figure.

> **Historical snapshot.** This measurement predates the current app shell and
> the `file_picker` dependency. It is retained as evidence for the stack
> decision; re-run the build command below for a current figure.

Measured on a purpose-built demo app (`com.kritha.kritha_size_demo`) that exercises the proposed
Kritha stack. The real Kritha repo was used only as a visual reference and was not modified.

## Result

| Metric | Value |
| --- | --- |
| Measured APK | `build/app/outputs/flutter-apk/app-release.apk` |
| Bytes | **57,014,424** |
| MiB (1 MiB = 1,048,576 B) | **54.373 MiB** |
| MB (decimal) | **57.014 MB** |
| Target | ≤ 60 MiB — **met**, 5.63 MiB headroom |
| SHA-256 | `f806f5db0689e7076d54aefd266eb7a5723bc84c110e434852f9aed002a49738` |
| Analysis JSON | `artifacts/apk-code-size-analysis.json` |
| Analyzed APK copy | `artifacts/kritha-size-demo-arm64-analyzed.apk` |

Build command:

```sh
flutter build apk --release --target-platform=android-arm64 --analyze-size
```

The final APK was rebuilt without `--analyze-size` and is **byte-identical** to the analyzed APK
(same SHA-256, same 57,014,424 bytes), so the analysis corresponds exactly to the delivered artifact.

## Size breakdown

### Native libraries — 53,142,896 B (93.2% of APK)

`.so` files are stored uncompressed in the APK for direct mmap, so stored size equals file size.

| Library | Bytes | % APK |
| --- | ---: | ---: |
| `lib/arm64-v8a/libonnxruntime.so` | 22,249,552 | 39.0% |
| `lib/arm64-v8a/libapp.so` (Dart AOT) | 12,321,672 | 21.6% |
| `lib/arm64-v8a/libflutter.so` (engine) | 11,747,864 | 20.6% |
| `lib/arm64-v8a/libsherpa-onnx-c-api.so` | 4,499,112 | 7.9% |
| `lib/arm64-v8a/libsqlite3.so` | 1,747,600 | 3.1% |
| `lib/arm64-v8a/libsherpa-onnx-cxx-api.so` | 437,880 | 0.8% |
| `lib/arm64-v8a/libdartjni.so` | 131,432 | 0.2% |
| `lib/arm64-v8a/libdatastore_shared_counter.so` | 7,784 | 0.01% |

Speech stack (`sherpa_onnx` + Android ARM64 runtime) totals **27,186,544 B (47.7% of the APK)**:
ONNX Runtime 22.25 MB, sherpa C API 4.50 MB, sherpa C++ API 0.44 MB. This is the single largest
cost in the build, before any model weights are added.

### Dart AOT (`libapp.so`) by package — 12,321,672 B

| Package | Bytes | % of AOT |
| --- | ---: | ---: |
| `val_latex` | 3,724,514 | 30.3% |
| `package:flutter` | 2,153,178 | 17.5% |
| `material_ui` | 675,959 | 5.5% |
| `gpt_markdown` | 410,154 | 3.3% |
| `drift` | 163,922 | 1.3% |
| `val_highlight` | 128,257 | 1.0% |
| `riverpod` | 103,127 | 0.8% |
| `val_latex_flutter` | 89,075 | 0.7% |
| App code (`package:kritha_size_demo`) | 79,798 | 0.6% |

LaTeX rendering (`val_latex` + `val_latex_flutter`) is **3,813,589 B**, about 31% of Dart code and
6.7% of the whole APK — larger than the entire Flutter framework portion.

### Fonts, assets, DEX

| Item | Uncompressed | Stored in APK | % APK |
| --- | ---: | ---: | ---: |
| Lucide icons (6 font files) | 2,995,132 | 1,402,216 | 2.5% |
| `classes.dex` | 1,978,832 | 998,611 | 1.8% |
| Latin Modern math fonts | 937,220 | 474,919 | 0.8% |
| Kritha logo (512×512 + launcher densities) | 339,056 | 339,056 | 0.6% |
| JetBrains Mono | 273,900 | 128,384 | 0.2% |

## Dependency versions (from `pubspec.lock`)

| Package | Version |
| --- | --- |
| `gpt_markdown` | 1.4.0 |
| `flutter_riverpod` | 3.4.3 |
| `go_router` | 18.1.1 |
| `drift` | 2.35.2 |
| `sqlite3` | 3.7.1 |
| `flutter_secure_storage` | 11.2.0 |
| `shared_preferences` | 2.5.6 |
| `dio` | 5.11.1 |
| `path_provider` | 2.1.6 |
| `freezed` | 4.0.3 |
| `freezed_annotation` | 3.1.0 |
| `json_serializable` | 6.15.2 |
| `json_annotation` | 4.12.0 |
| `lucide_icons_flutter` | 4.0.1 |
| `sherpa_onnx` | 1.13.8 |
| `sherpa_onnx_android_arm64` | 1.13.8 |
| `record` | 7.1.2 |
| `just_audio` | 0.10.6 |
| `permission_handler` | 13.0.2 |
| `material_ui` | 1.8.0 |
| `build_runner` (dev) | 2.16.2 |

## Verification performed

- `flutter pub get` resolved cleanly; `dart format lib test` clean; `flutter analyze` → **No issues found**; `flutter test` → **7/7 passed**.
- Every listed dependency is imported and exercised at runtime: routing, Riverpod state, Drift/SQLite
  queries, secure storage, prefs, Dio client, audio recording/playback, and sherpa-onnx API objects are
  constructed (no model download, no bundled weights).
- APK contains **only** `lib/arm64-v8a/`; no `armeabi-v7a`, `x86`, or `x86_64` natives.
- Every bundled `.so` was checked as ELF `AArch64`.
- No model weights, no ONNX models, no LiteRT-LM runtime. The only `.bin` entries are
  `assets/flutter_assets/AssetManifest.bin` and `DebugProbesKt.bin`.
- Manifest: `com.kritha.kritha_size_demo`, version `1.0.0` (1), minSdk 24, targetSdk 36, compileSdk 37,
  `RECORD_AUDIO` permission. Signed with the debug key.

## Limitations

1. **`lucide_icons` substituted with `lucide_icons_flutter` 4.0.1.** `lucide_icons` 0.257.0 declares
   `sdk: <3.0.0` and cannot resolve on Dart 3.13. `lucide_icons_flutter` is the maintained equivalent.
2. **Lucide ships all six variable-weight fonts** (~2.99 MB raw / 1.40 MB stored) although the demo
   only uses one weight; a production app could trim this.
3. **ABI filtering workaround.** Flutter 3.47's `--target-platform=android-arm64` did not filter plugin
   AAR ABIs, so `ndk.abiFilters` and `packaging.jniLibs.excludes` were added in
   `android/app/build.gradle.kts`. This is a minimal platform config change, no custom Kotlin/Swift.
4. **`compileSdk 37`** is required by `permission_handler_android` 13.0.2.
5. **Release signed with the debug key**, suitable for size measurement only.
6. **No on-device execution run.** Size and packaging were verified statically on the artifact; the app
   was not profiled on a physical ARM64 device.
7. Build emits a warning about a missing `cupertino_icons` font; no Cupertino icons are used.
8. `--target-platform` still produces a single universal APK filtered to ARM64 (not `--split-per-abi`),
   as specified.
9. The demo implements no real backend, auth, encryption, AI inference, wake-word, or Live Talk path;
   only API initialization and UI/state/data plumbing are measured.
