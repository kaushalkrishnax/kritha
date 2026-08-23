import { useCallback, useReducer } from 'react';
import {
  ChatMessage,
  DownloadState,
  ModelRecord,
} from '../components/chat/types';
import { ChatSession } from '../services/db.service';

//  State shape

export type AssistantBannerState = {
  status: 'idle' | 'listening' | 'processing' | 'streaming';
  transcript?: string;
};

export type ChatState = {
  // Conversation
  sessionId: string | null;
  sessions: ChatSession[];
  messages: ChatMessage[];
  isSending: boolean;
  error: string | null;
  assistantBanner: AssistantBannerState;

  // Models
  models: ModelRecord[];
  selectedModelId: string;
  downloadState: DownloadState;

  // Dictation / voice
  isRecording: boolean;
  draft: string;
  preDictationDraft: string;

  // UI
  isWakeWordOn: boolean;
  sidebarOpen: boolean;
  localDevice: 'cpu' | 'gpu';
  
  ttsState: {
    isSpeaking: boolean;
    isPaused: boolean;
    msgId: string | null;
  };
};

//  Actions

export type ChatAction =
  // Conversation
  | { type: 'ADD_MESSAGE'; payload: ChatMessage }
  | { type: 'STREAM_CHUNK'; id: string; chunk: string }
  | { type: 'SET_SENDING'; value: boolean }
  | { type: 'SET_ERROR'; error: string | null }
  | { type: 'SET_ASSISTANT_BANNER'; banner: AssistantBannerState }
  | { type: 'FINISH_ASSISTANT_STREAM'; id: string; fullText: string }
  | { type: 'SET_SESSIONS'; sessions: ChatSession[] }
  | { type: 'SET_SESSION_ID'; sessionId: string | null }
  | { type: 'SET_MESSAGES'; messages: ChatMessage[] }
  // Models
  | { type: 'SET_MODELS'; models: ModelRecord[] }
  | { type: 'SET_SELECTED_MODEL'; modelId: string }
  | { type: 'MARK_MODEL_DOWNLOADED'; modelId: string }
  | { type: 'UPDATE_DOWNLOAD'; patch: Partial<DownloadState> }
  // Dictation
  | { type: 'SET_RECORDING'; value: boolean }
  | { type: 'SET_DRAFT'; text: string }
  | { type: 'SET_PRE_DICTATION_DRAFT'; text: string }
  // UI
  | { type: 'TOGGLE_WAKE_WORD'; value: boolean }
  | { type: 'TOGGLE_SIDEBAR'; value: boolean }
  | { type: 'SET_DEVICE'; device: 'cpu' | 'gpu' }
  | { type: 'SET_TTS_STATE'; state: { isSpeaking: boolean; isPaused: boolean; msgId: string | null } };

//  Reducer

const BASE_MODELS: ModelRecord[] = [
  {
    id: 'gemini-flash-lite-latest',
    name: 'Gemini Flash Lite Latest',
    provider: 'Google Cloud',
    downloaded: true,
    isCloud: true,
  },
  {
    id: 'gemma-4-E2B-it',
    name: 'Gemma 4 E2B',
    provider: 'Hugging Face',
    downloaded: false,
  },
  {
    id: 'gemma-4-E4B-it',
    name: 'Gemma 4 E4B',
    provider: 'Hugging Face',
    downloaded: false,
  },
  {
    id: 'Qwen3-1.7B',
    name: 'Qwen 3 1.7B',
    provider: 'Hugging Face',
    downloaded: false,
  },
  {
    id: 'Qwen3-4B-Thinking-2507',
    name: 'Qwen 3 4B Thinking 2507',
    provider: 'Hugging Face',
    downloaded: false,
  },
];

const INITIAL_STATE: ChatState = {
  sessionId: null,
  sessions: [],
  messages: [],
  isSending: false,
  error: null,
  assistantBanner: { status: 'idle' },

  models: BASE_MODELS,
  selectedModelId: 'gemma-4-E2B-it',
  downloadState: {
    modelId: '',
    progress: 0,
    downloadedMb: 0,
    totalMb: 0,
    speed: 0,
    active: false,
    paused: false,
  },

  isRecording: false,
  draft: '',
  preDictationDraft: '',

  isWakeWordOn: true,
  sidebarOpen: false,
  localDevice: 'cpu',
  
  ttsState: {
    isSpeaking: false,
    isPaused: false,
    msgId: null,
  },
};

function chatReducer(state: ChatState, action: ChatAction): ChatState {
  switch (action.type) {
    case 'SET_SESSIONS':
      return { ...state, sessions: action.sessions };

    case 'SET_SESSION_ID':
      return { ...state, sessionId: action.sessionId };

    case 'SET_MESSAGES':
      return { ...state, messages: action.messages };

    case 'ADD_MESSAGE':
      return { ...state, messages: [...state.messages, action.payload] };

    case 'STREAM_CHUNK':
      return {
        ...state,
        messages: state.messages.map((m) =>
          m.id === action.id ? { ...m, text: m.text + action.chunk } : m,
        ),
      };

    case 'FINISH_ASSISTANT_STREAM':
      return {
        ...state,
        messages: state.messages.map((m) =>
          m.id === action.id ? { ...m, text: action.fullText || m.text } : m,
        ),
      };

    case 'SET_SENDING':
      return { ...state, isSending: action.value };

    case 'SET_ERROR':
      return { ...state, error: action.error };

    case 'SET_ASSISTANT_BANNER':
      return { ...state, assistantBanner: action.banner };

    case 'SET_MODELS':
      return { ...state, models: action.models };

    case 'SET_SELECTED_MODEL':
      return { ...state, selectedModelId: action.modelId };

    case 'MARK_MODEL_DOWNLOADED':
      return {
        ...state,
        models: state.models.map((m) =>
          m.id === action.modelId ? { ...m, downloaded: true } : m,
        ),
        selectedModelId: action.modelId,
      };

    case 'UPDATE_DOWNLOAD':
      return {
        ...state,
        downloadState: { ...state.downloadState, ...action.patch },
      };

    case 'SET_RECORDING':
      return { ...state, isRecording: action.value };

    case 'SET_DRAFT':
      return { ...state, draft: action.text };

    case 'SET_PRE_DICTATION_DRAFT':
      return { ...state, preDictationDraft: action.text };

    case 'TOGGLE_WAKE_WORD':
      return { ...state, isWakeWordOn: action.value };

    case 'TOGGLE_SIDEBAR':
      return { ...state, sidebarOpen: action.value };

    case 'SET_DEVICE':
      return { ...state, localDevice: action.device };

    case 'SET_TTS_STATE':
      return { ...state, ttsState: action.state };

    default:
      return state;
  }
}

// Hook

export function useChatState() {
  const [state, dispatch] = useReducer(chatReducer, INITIAL_STATE);

  const stableDispatch = useCallback(dispatch, []);

  return { state, dispatch: stableDispatch };
}
