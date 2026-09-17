/* eslint-disable @typescript-eslint/no-redeclare */

export const LlmPhase = {
  IDLE: 'LLM_IDLE',
  SUBMITTING: 'LLM_SUBMITTING',
  THINKING: 'LLM_THINKING',
  GENERATING: 'LLM_GENERATING',
  ERROR: 'LLM_ERROR',
} as const;
export type LlmPhase = (typeof LlmPhase)[keyof typeof LlmPhase];

export const SttPhase = {
  IDLE: 'STT_IDLE',
  LISTENING: 'STT_LISTENING',
  TRANSCRIBING: 'STT_TRANSCRIBING',
  ERROR: 'STT_ERROR',
} as const;
export type SttPhase = (typeof SttPhase)[keyof typeof SttPhase];

export const TtsPhase = {
  IDLE: 'TTS_IDLE',
  SPEAKING: 'TTS_SPEAKING',
  PAUSED: 'TTS_PAUSED',
  ERROR: 'TTS_ERROR',
} as const;
export type TtsPhase = (typeof TtsPhase)[keyof typeof TtsPhase];

export const ChatMode = {
  TEXTING: 'CHAT_MODE_TEXTING',
  DICTATION: 'CHAT_MODE_DICTATION',
  LIVE_TALK: 'CHAT_MODE_LIVE_TALK',
} as const;
export type ChatMode = (typeof ChatMode)[keyof typeof ChatMode];

export const LiveTalkPhase = {
  LISTENING: 'LIVE_TALK_LISTENING',
  SPEAKING: 'LIVE_TALK_SPEAKING',
  PAUSED: 'LIVE_TALK_PAUSED',
} as const;
export type LiveTalkPhase = (typeof LiveTalkPhase)[keyof typeof LiveTalkPhase];

export const RequestOrigin = {
  MANUAL_TYPING: 'MANUAL_TYPING',
  MANUAL_DICTATION: 'MANUAL_DICTATION',
  LIVE_TALK: 'LIVE_TALK',
  WAKE_WORD: 'WAKE_WORD',
  VOICE_INTERACTION: 'VOICE_INTERACTION',
} as const;
export type RequestOrigin = (typeof RequestOrigin)[keyof typeof RequestOrigin];

export const MicOwner = {
  NONE: 'MIC_OWNER_NONE',
  STT: 'MIC_OWNER_STT',
  WAKE_WORD: 'MIC_OWNER_WAKE_WORD',
} as const;
export type MicOwner = (typeof MicOwner)[keyof typeof MicOwner];
