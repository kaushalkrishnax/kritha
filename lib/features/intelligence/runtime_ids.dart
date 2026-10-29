/// Canonical source/provider and runtime identifiers.
///
/// A source identifies where a model came from (a local inventory or a
/// configured provider). A runtime identifies the adapter that executes it.
/// Several sources can share one runtime, for example OpenAI, Mistral and a
/// custom endpoint all use [openAiRuntimeId].
const localProviderId = 'local-litertlm';
const localRuntimeId = 'litertlm';
const openAiRuntimeId = 'openai';
const anthropicRuntimeId = 'anthropic';
const geminiRuntimeId = 'gemini';
