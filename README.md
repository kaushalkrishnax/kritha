<div align="center">

<img src="assets/images/kritha_logo.png" alt="Kritha" width="100" height="100" />

# Kritha

### A Voice-First, Privacy-First AI Assistant

**Your voice. Your device. Your data — on-device intelligence for Android, iOS and desktop.**

<br/>

<p>
  <a href="https://github.com/kaushalkrishnax/kritha"><img src="https://img.shields.io/github/stars/kaushalkrishnax/kritha?label=Stars&color=2563EB&style=flat-square" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-3DDC84?style=flat-square" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.7-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.13.5-0175C2?style=flat-square&logo=dart&logoColor=white" />
</p>

<p>
  <img src="https://img.shields.io/badge/Android-arm64%20%7C%20x86__64-3DDC84?style=flat-square&logo=android&logoColor=white" />
  <img src="https://img.shields.io/badge/iOS-arm64-000000?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/macOS-universal-000000?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Windows-x86__64-0078D4?style=flat-square&logo=windows&logoColor=white" />
</p>

</div>

---

### 📌 Table of Contents

- [⬇ Build & Download](#-build--download)
- [✨ Highlights](#-highlights)
- [🔌 Tech](#-tech)
- [📸 Preview](#-preview)
- [🚀 Quick Start](#-quick-start)
- [✅ Verification](#-verification)
- [📚 Documentation](#-documentation)
- [🛠 Troubleshooting](#-troubleshooting)
- [⚖ Legal Notice](#-legal-notice)

---

## ⬇ Build & Download

**Current version:** `1.0.0` · Android 8.0+ · iOS 15+ · macOS 12+ · Windows 10/11

Release artifacts are built locally under `dist/` and published on the
[GitHub releases page](https://github.com/kaushalkrishnax/kritha/releases).

| Build Variant | Targets | Command |
| --- | --- | --- |
| **Android APKs** | `arm64-v8a`, `x86_64` | `npm run build:android` |
| **Android App Bundle** | Both Android ABIs | `npm run build:aab` |
| **iOS IPA** | `arm64` device | `npm run build:app` |
| **iOS local build** | `arm64` unsigned | `npm run build:ios` |
| **macOS apps** | `arm64` and `x86_64` | `npm run build:macos` |
| **Windows archive** | `x86_64` | `npm run build:windows` |

> **Quick guide:** Not sure which Android build to pick? Use **arm64-v8a** — it
> covers modern phones and tablets. Emulator users should pick **x86_64**.

---

## ✨ Highlights

<div align="center">
  <table>
    <tr>
      <td width="50%" align="center">
      <br/>💬
      <h3>Conversation that adapts</h3>
      <sub>Responsive shell, persistent sessions, keyboard-aware composer and one shared context-menu language.</sub>
      <br/><br/>
      </td>
      <td width="50%" align="center">
      <br/>🧠
      <h3>On-device intelligence</h3>
      <sub>Local LiteRT-LM inference behind explicit lifecycle controls — no silent downloads or hidden model loading.</sub>
      <br/><br/>
      </td>
    </tr>
    <tr>
      <td width="50%" align="center">
      <br/>📦
      <h3>Models, on demand</h3>
      <sub>Discover LiteRT-LM repositories on the Hub, inspect files, prepare artifacts and resume large downloads.</sub>
      <br/><br/>
      </td>
      <td width="50%" align="center">
      <br/>🔐
      <h3>Privacy by default</h3>
      <sub>Local SQLite history, platform secure storage and provider keys that are never rendered back into the UI.</sub>
      <br/><br/>
      </td>
    </tr>
  </table>
</div>

---

## 🔌 Tech

| Area | Technology |
| --- | --- |
| UI | Flutter · Material · custom design system |
| State | Riverpod |
| Persistence | Drift · SQLite · SharedPreferences |
| Secrets | Android Keystore / Apple Keychain via secure storage |
| Local AI | LiteRT-LM · sherpa ONNX |
| Wake word | Edge Impulse (Android foreground service) |
| Cloud LLM | OpenAI-compatible APIs · Anthropic Messages · Gemini |
| Catalogue | Hugging Face Hub API |
| Tooling | Dart · Node.js release scripts |

---

## 📸 Preview

Screenshots coming soon.

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version | Notes |
| --- | --- | --- |
| **Flutter** | 3.47.7 | Dart 3.13.5 |
| **Xcode** | Latest | iOS and macOS builds |
| **Android SDK** | API 26+ | Android builds |
| **Visual Studio 2022** | Latest | Windows desktop builds, with the Desktop development with C++ workload |

### Installation

```bash
git clone https://github.com/kaushalkrishnax/kritha.git
cd kritha

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

`build_runner` regenerates the Drift, Freezed and JSON serialisation sources.
They are checked in, so the app runs without it unless you change a model or
table.

### Signed release builds

Create local signing files from the checked-in examples:

```bash
cp android/key.example.properties android/key.properties
cp ios/Flutter/Signing.xcconfig.example ios/Flutter/Signing.xcconfig
cp ios/ExportOptions.plist.example ios/ExportOptions.plist
cp macos/Runner/Configs/Signing.xcconfig.example macos/Runner/Configs/Signing.xcconfig
```

Fill in the Android passwords, key alias and keystore path in
`android/key.properties`. The sample `../upload-keystore.jks` path is resolved
relative to `android/app/`, so the keystore belongs at
`android/upload-keystore.jks`. The release Gradle tasks fail rather than
silently signing with a debug key.

For Apple distribution, set your Apple Developer Team ID in the local xcconfig
files and Xcode export plist, then install the matching certificates and
provisioning profiles in Xcode. Local macOS builds use ad-hoc signing for build
verification; replace it with `Developer ID Application` or
`Apple Distribution` before distribution.

```bash
npm run build:android  # signed APKs for arm64-v8a and x86_64
npm run build:aab      # signed AAB with both Android ABIs
npm run build:ios      # unsigned arm64 iOS device build
npm run build:app      # signed arm64 IPA for App Store Connect
npm run build:macos    # signed arm64 + x86_64 macOS apps
npm run build:windows  # Windows x64 release, from a Windows host
```

Version bumps use `npm run bump:beta` or `npm run bump:release`. The scripts
update `pubspec.yaml` and `package.json`; commit those changes, rerun the
command to create a local tag, and push the tag after reviewing it.

---

## ✅ Verification

```bash
dart format lib test
flutter analyze
flutter test
```

The test suite covers the design system, responsive shell, composer, sessions,
persistence, intelligence contracts, model catalogue and filters, artifact
setup and downloads, providers, secure storage and shared widgets.

`pubspec.yaml` pins `shared_preferences_foundation` 2.5.7 because its 2.6.0
Swift source uses trailing commas that Xcode 16.2's Swift 6.0.3 rejects. Remove
the override when the iOS toolchain is upgraded.

---

## 📚 Documentation

| Document | Contents |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Runtime layers, composer, sessions, intelligence, models and providers, project layout and known gaps |
| [`docs/DESIGN_CONVENTIONS.md`](docs/DESIGN_CONVENTIONS.md) | Tokens, typography, colour, spacing, responsive rules and the change checklist |
| [`docs/BUTTONS.md`](docs/BUTTONS.md) | Every button, row and menu control, sizing, states and press/focus feedback |
| [`docs/UI_PATTERNS.md`](docs/UI_PATTERNS.md) | Shell, header, sidebar, composer, dictation, Live Talk and overlay patterns |
| [`docs/COMPONENTS.md`](docs/COMPONENTS.md) | Component inventory, status and hand-off notes |

---

## 🛠 Troubleshooting

<details>
<summary><b>📱 App crashes on launch</b></summary>

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

</details>

<details>
<summary><b>🎙️ Wake word never triggers</b></summary>

1. Complete the permissions checklist in **Settings**
2. Keep the wake-word foreground service enabled
3. Make sure no other app holds the microphone

</details>

<details>
<summary><b>🔇 No audio after model download</b></summary>

- Re-download your TTS model in **Settings → Voice**
- Confirm the required runtime is installed
- Check the Media volume on your device

</details>

<details>
<summary><b>🐘 Build / Gradle issues</b></summary>

```bash
cd android && ./gradlew clean && rm -rf .gradle && cd ..
flutter clean
flutter pub get
npm run build:android
```

</details>

<details>
<summary><b>🍎 Xcode or CocoaPods issues</b></summary>

```bash
cd ios && pod install --repo-update && cd ..
flutter clean
flutter pub get
```

</details>

---

## ⚖ Legal Notice

**Kritha is an independent project.** Not affiliated with, endorsed by, or
connected to Google, LiteRT, Hugging Face, or any model provider. On-device
models come from their public sources; nothing is redistributed. Kritha is
licensed under the GNU General Public License v3.0 or later.

---

## License

**GNU GPL v3.0 or later** © 2026 Kritha · See [LICENSE](LICENSE)

---

Built with a focus on **privacy, correctness, and longevity.**
