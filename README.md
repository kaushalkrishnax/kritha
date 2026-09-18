<div align="center">

<img src="assets/images/splash-icon.png" alt="Kritha" width="100" height="100" />

# Kritha

### A Voice-First, Privacy-First AI Assistant

**Your voice. Your device. Your data — on-device intelligence with a native Android assistant runtime.**

<br/>

<p>
  <a href="https://github.com/kaushalkrishnax/kritha/releases/tag/v0.1.0"><img src="https://img.shields.io/github/v/release/kaushalkrishnax/kritha?label=Release&color=2563EB&style=flat-square" /></a>
  <a href="https://github.com/kaushalkrishnax/kritha/releases"><img src="https://img.shields.io/github/downloads/kaushalkrishnax/kritha/total?label=Downloads&color=3DDC84&style=flat-square" /></a>
  <a href="https://github.com/kaushalkrishnax/kritha"><img src="https://img.shields.io/github/stars/kaushalkrishnax/kritha?label=Stars&color=FAFBFC&style=flat-square" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-10B981?style=flat-square" /></a>
</p>

<p>
  <img src="https://img.shields.io/badge/React_Native-0.86-61DAFB?style=flat-square&logo=react&logoColor=white" />
  <img src="https://img.shields.io/badge/Expo-57-000020?style=flat-square&logo=expo&logoColor=white" />
  <img src="https://img.shields.io/badge/Kotlin-0095D5?style=flat-square&logo=kotlin&logoColor=white" />
  <img src="https://img.shields.io/badge/LiteRT-FF6F00?style=flat-square&logo=tensorflow&logoColor=white" />
  <img src="https://img.shields.io/badge/Edge_Impulse-1B1F23?style=flat-square&logo=generic&logoColor=white" />
  <img src="https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white" />
</p>

</div>

---

### 📌 Table of Contents

- [⬇ Download](#-download)
- [✨ Highlights](#-highlights)
- [🔌 Tech](#-tech)
- [📸 Preview](#-preview)
- [🚀 Quick Start](#-quick-start)
- [🛠 Troubleshooting](#-troubleshooting)
- [⚖ Legal Notice](#-legal-notice)

---

## ⬇ Download

**Current Version:** `v0.1.0` · Android 7.0+ · ~80 MB

| Build Variant   | Device Compatibility        | Download                                                                        |
| --------------- | --------------------------- | ------------------------------------------------------------------------------- |
| **arm64-v8a**   | Modern Android devices      | [![Download arm64-v8a](https://img.shields.io/badge/Download-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/kaushalkrishnax/kritha/releases/download/v0.1.0/Kritha-0.1.0-arm64-v8a.apk) |
| **x86_64**      | Emulators and x86_64 devices | [![Download x86_64](https://img.shields.io/badge/Download-0288D1?style=for-the-badge&logo=android&logoColor=white)](https://github.com/kaushalkrishnax/kritha/releases/download/v0.1.0/Kritha-0.1.0-x86_64.apk) |

> **Quick Guide:** Not sure? Pick **arm64-v8a** — it covers virtually every phone made since 2017. Emulator users should pick **x86_64**.

---

## ✨ Highlights

<div align="center">
  <table>
    <tr>
      <td width="50%" align="center">
      <br/>💬
      <h3>Talk to your phone</h3>
      <sub>Hands-free Live Talk, dictation, and a “Hey Kritha” wake word that works from anywhere.</sub>
      <br/><br/>
      </td>
      <td width="50%" align="center">
      <br/>🧠
      <h3>On-device intelligence</h3>
      <sub>Local LLMs (Gemma, Qwen) via LiteRT — with Gemini as an optional cloud fallback.</sub>
      <br/><br/>
      </td>
    </tr>
    <tr>
      <td width="50%" align="center">
      <br/>📦
      <h3>Models, on demand</h3>
      <sub>Download the runtimes and voice models you want — LiteRT, LiteRT-LM, ONNX, Kitten TTS, Qwen3-TTS.</sub>
      <br/><br/>
      </td>
      <td width="50%" align="center">
      <br/>🤖
      <h3>Your own assistant</h3>
      <sub>Custom automations and workflows, persistent native chat, deep Android integration.</sub>
      <br/><br/>
      </td>
    </tr>
  </table>
</div>

---

## 🔌 Tech

| Area          | Technology                                            |
| ------------- | ----------------------------------------------------- |
| UI            | React Native · Tamagui · Zustand                      |
| Framework     | Expo SDK 57                                           |
| Native        | Kotlin assistant runtime                              |
| Local AI      | LiteRT · LiteRT-LM · ONNX (on-demand)                |
| Wake word     | Edge Impulse                                          |
| Cloud LLM     | Gemini (optional)                                     |
| Persistence   | Native SQLite                                         |
| Package mgr   | Bun                                                   |

---

## 📸 Preview

Screenshots coming soon.

---

## 🚀 Quick Start

### Prerequisites

| Requirement                 | Version        | Download                                              |
| --------------------------- | -------------- | ----------------------------------------------------- |
| **Node.js**                 | 18.x or higher | [nodejs.org](https://nodejs.org/)                     |
| **Bun**                     | Latest         | [bun.sh](https://bun.sh/)                              |
| **Android SDK**             | Latest         | Via Android Studio                                    |
| **Android Device/Emulator** | API 24+        | [Android Studio](https://developer.android.com/studio) |

> **⚠️ Note:** Kritha ships custom native Android code, so **Expo Go is not supported** — use a development build.

### Installation

```bash
git clone https://github.com/kaushalkrishnax/kritha.git
cd kritha

bun install
bun run android
npx expo start --dev-client
```

---

## 🛠 Troubleshooting

<details>
<summary><b>📱 App crashes on launch</b></summary>

```bash
bun run android
npx expo start -c
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

- Re-download your TTS model in the **Voice Models** panel
- Confirm the required runtime is installed
- Check the Media volume on your device

</details>

<details>
<summary><b>🐘 Build / Gradle issues</b></summary>

```bash
cd android && ./gradlew clean && rm -rf .gradle && cd ..
bun run android
```

</details>

---

## ⚖ Legal Notice

**Kritha is an independent project.** Not affiliated with, endorsed by, or connected to Google, LiteRT, or any model provider. On-device models come from their public sources; nothing is redistributed. For **educational and personal use only**.

---

## License

**MIT** © 2026 Kritha · See [LICENSE](LICENSE)

---

Built with a focus on **privacy, correctness, and longevity.**