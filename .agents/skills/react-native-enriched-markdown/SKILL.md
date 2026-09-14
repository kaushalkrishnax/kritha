---
name: react-native-enriched-markdown
description: >-
  Use the vendored enriched-markdown documentation when implementing,
  debugging, reviewing, or answering questions about
  react-native-enriched-markdown. Prefer the exact docs in this skill
  over memory or assumptions, especially for API names, props, defaults,
  platform behavior, and version-specific behavior.
---

# React Native Enriched Markdown

Documentation source: `software-mansion/enriched-markdown`
Pinned commit: `78d397d9e48b492b47c67416087f958a4602e490`

## Agent instructions

1. Treat `docs/API_REFERENCE.md` as the primary source of truth for the
   public API: props, types, callbacks, events, ref methods, and defaults.
2. For a feature-specific question, read the most relevant document below
   before proposing code. Do not invent props, callbacks, or platform support.
3. Check `docs/BREAKING_CHANGES.md` when behavior may depend on the library
   version or when migrating existing code.
4. Check platform-specific documentation (`MACOS.md` or `WEB.md`) when the
   question concerns a non-iOS/Android target.
5. For streaming/LLM Markdown, consult `MARKDOWN_STREAMING.md` and then
   `API_REFERENCE.md` for the exact prop/type definitions.
6. For rendering/styling questions, use `TEXT.md`, `ELEMENTS_STRUCTURE.md`,
   `STYLES.md`, and `API_REFERENCE.md` as appropriate.
7. For input/editor questions, use `INPUT.md`, `MENTIONS.md`, and
   `API_REFERENCE.md` as appropriate.
8. For native build/install problems, check `NATIVE_ASSETS.md` and the
   relevant platform documentation before suggesting native changes.
9. If the local docs do not answer a question, say so explicitly instead
   of fabricating behavior. The docs are pinned to the commit above.

## Documentation index

- `docs/ACCESSIBILITY.md`: Accessibility behavior, semantics, VoiceOver/TalkBack, and accessibility-related props.
- `docs/API_REFERENCE.md`: Complete public API reference: components, props, types, events, callbacks, ref methods, and defaults. Treat this as the primary API source of truth.
- `docs/BREAKING_CHANGES.md`: Breaking changes, migration notes, and release-specific behavior.
- `docs/CODE_HIGHLIGHT.md`: Code block rendering and syntax highlighting configuration, languages, and related behavior.
- `docs/COPY_OPTIONS.md`: Native selection/copy behavior, Smart Copy, Copy as Markdown, Copy Image URL, and selectionMenuConfig.
- `docs/ELEMENTS_STRUCTURE.md`: Supported Markdown element structure and how Markdown elements map to rendered/native structures.
- `docs/IMAGE_CACHING.md`: Image loading/caching behavior and configuration for remote/local images.
- `docs/INPUT.md`: EnrichedMarkdownTextInput usage, editing behavior, events, formatting, links, mentions, and input-specific configuration.
- `docs/LATEX_MATH.md`: Inline/block LaTeX math support, syntax, configuration, platform behavior, and limitations.
- `docs/MACOS.md`: macOS support, platform-specific behavior, setup, and known limitations.
- `docs/MARKDOWN_STREAMING.md`: Streaming Markdown/LLM rendering, incomplete Markdown handling, streamingAnimation, streamingConfig, and table/code streaming behavior.
- `docs/MENTIONS.md`: Mentions in EnrichedMarkdownTextInput, mention detection, rendering, and related configuration.
- `docs/NATIVE_ASSETS.md`: Native dependency/vendor asset downloads, postinstall behavior, package-manager notes, and opt-outs.
- `docs/RTL.md`: Right-to-left text and layout behavior, configuration, and platform-specific considerations.
- `docs/STYLES.md`: MarkdownStyle and styling of headings, paragraphs, lists, links, code, images, tables, math, and other rendered elements.
- `docs/TESTING.md`: Jest/testing setup, native component mocks, imperative ref methods, and testing limitations.
- `docs/TEXT.md`: EnrichedMarkdownText usage, supported Markdown features, rendering behavior, callbacks, and text-specific configuration.
- `docs/WEB.md`: Web renderer support, react-native-web behavior, semantic HTML, supported features, and web-specific limitations.

## Routing guide

| Question                                  | Read first                                    |
| ----------------------------------------- | --------------------------------------------- |
| API props/types/ref methods/events        | `API_REFERENCE.md`                            |
| Markdown rendering / EnrichedMarkdownText | `TEXT.md`, `API_REFERENCE.md`                 |
| Text/input editor                         | `INPUT.md`, `API_REFERENCE.md`                |
| Styling                                   | `STYLES.md`, `API_REFERENCE.md`               |
| Markdown element behavior                 | `ELEMENTS_STRUCTURE.md`                       |
| Streaming LLM output                      | `MARKDOWN_STREAMING.md`, `API_REFERENCE.md`   |
| Code blocks / syntax highlighting         | `CODE_HIGHLIGHT.md`, `API_REFERENCE.md`       |
| LaTeX / math                              | `LATEX_MATH.md`, `API_REFERENCE.md`           |
| Images / image caching                    | `IMAGE_CACHING.md`, `API_REFERENCE.md`        |
| Links / mentions                          | `MENTIONS.md`, `INPUT.md`, `API_REFERENCE.md` |
| Copy / selection menus                    | `COPY_OPTIONS.md`, `API_REFERENCE.md`         |
| Accessibility                             | `ACCESSIBILITY.md`, `API_REFERENCE.md`        |
| RTL                                       | `RTL.md`, `API_REFERENCE.md`                  |
| Web                                       | `WEB.md`, `API_REFERENCE.md`                  |
| macOS                                     | `MACOS.md`, `API_REFERENCE.md`                |
| Native asset/install failures             | `NATIVE_ASSETS.md`                            |
| Jest/testing                              | `TESTING.md`                                  |
| Migration/breaking behavior               | `BREAKING_CHANGES.md`                         |

## Working rule

Read only the relevant docs needed for the task, but always verify exact
API names and signatures against `API_REFERENCE.md` before writing code.
When two documents appear to conflict, prefer the pinned documentation
for the specific feature and note the discrepancy rather than guessing.
