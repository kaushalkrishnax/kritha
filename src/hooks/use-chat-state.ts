import { useCallback, useReducer } from 'react';
import { DownloadState, ModelRecord } from '../components/chat/types';

export type ChatState = {
  models: ModelRecord[];
  selectedModelId: string;
  downloadState: DownloadState;
  isWakeWordOn: boolean;
  sidebarOpen: boolean;
  localDevice: 'cpu' | 'gpu';
};

export type ChatAction =
  | { type: 'SET_MODELS'; models: ModelRecord[] }
  | { type: 'SET_SELECTED_MODEL'; modelId: string }
  | { type: 'MARK_MODEL_DOWNLOADED'; modelId: string }
  | { type: 'UPDATE_DOWNLOAD'; patch: Partial<DownloadState> }
  | { type: 'TOGGLE_WAKE_WORD'; value: boolean }
  | { type: 'TOGGLE_SIDEBAR'; value: boolean }
  | { type: 'SET_DEVICE'; device: 'cpu' | 'gpu' };

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
  isWakeWordOn: true,
  sidebarOpen: false,
  localDevice: 'cpu',
};

function chatReducer(state: ChatState, action: ChatAction): ChatState {
  switch (action.type) {
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
    case 'TOGGLE_WAKE_WORD':
      return { ...state, isWakeWordOn: action.value };
    case 'TOGGLE_SIDEBAR':
      return { ...state, sidebarOpen: action.value };
    case 'SET_DEVICE':
      return { ...state, localDevice: action.device };
    default:
      return state;
  }
}

export function useChatState() {
  const [state, dispatch] = useReducer(chatReducer, INITIAL_STATE);
  const stableDispatch = useCallback(dispatch, []);
  return { state, dispatch: stableDispatch };
}