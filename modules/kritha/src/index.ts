import { EventSubscription } from 'expo-modules-core';
import KrithaModule, {
  AssistantCommand,
  AssistantEvent,
  CanonicalAssistantState,
  DownloadProgressEvent,
  MicOwner,
  ModelMetadata,
  NativeChatSession,
  RequestOrigin,
  WakeWordEvent,
} from './KrithaModule';

const emitter = KrithaModule;

export function dispatchCommand(command: AssistantCommand): boolean {
  return KrithaModule.dispatchCommand(command);
}

export function getCurrentState() {
  return KrithaModule.getCurrentState();
}

export function submitText(
  text: string,
  options?: {
    chatSessionId?: string;
    modelId?: string;
    origin?: RequestOrigin;
  },
): boolean {
  return dispatchCommand({
    type: 'SUBMIT_TEXT',
    text,
    chatSessionId: options?.chatSessionId,
    modelId: options?.modelId,
    origin: options?.origin,
  });
}

export function startListening(
  chatSessionId?: string,
  assistantRunId?: string,
): boolean {
  return dispatchCommand({
    type: 'START_LISTENING',
    chatSessionId,
    assistantRunId,
  });
}

export function stopListening(): boolean {
  return dispatchCommand({ type: 'STOP_LISTENING' });
}

export function playTts(
  text: string,
  options?: {
    chatSessionId?: string;
    assistantRunId?: string;
    messageId?: string;
  },
): boolean {
  return dispatchCommand({
    type: 'PLAY_TTS',
    text,
    chatSessionId: options?.chatSessionId,
    assistantRunId: options?.assistantRunId,
    messageId: options?.messageId,
  });
}

export function pauseTts(): boolean {
  return dispatchCommand({ type: 'PAUSE_TTS' });
}

export function resumeTts(): boolean {
  return dispatchCommand({ type: 'RESUME_TTS' });
}

export function stopTts(): boolean {
  return dispatchCommand({ type: 'STOP_TTS' });
}

export function cancel(assistantRunId?: string, requestId?: string): boolean {
  return dispatchCommand({ type: 'CANCEL', assistantRunId, requestId });
}

export function dismiss(): boolean {
  return dispatchCommand({ type: 'DISMISS' });
}

export function openMainApp(): boolean {
  return dispatchCommand({ type: 'OPEN_MAIN_APP' });
}

export function loadSessions(): NativeChatSession[] {
  return KrithaModule.loadSessions() || [];
}

export function beginNewChat(): void {
  KrithaModule.beginNewChat();
}

export function openChat(sessionId: string): void {
  KrithaModule.openChat(sessionId);
}

export function renameChat(id: string, title: string): boolean {
  return KrithaModule.renameChat(id, title);
}

export function pinChat(id: string, pinned: boolean): boolean {
  return KrithaModule.pinChat(id, pinned);
}

export function archiveChat(id: string, archived: boolean): boolean {
  return KrithaModule.archiveChat(id, archived);
}

export function deleteChat(id: string): boolean {
  return KrithaModule.deleteChat(id);
}

export function start(): void {
  KrithaModule.start();
}

export function stop(): void {
  KrithaModule.stop();
}

export function isRunning(): boolean {
  return KrithaModule.isRunning();
}

export function setCloudApiKey(apiKey: string): void {
  KrithaModule.setCloudApiKey(apiKey);
}

export function getCustomInstructions(): string {
  return KrithaModule.getCustomInstructions();
}

export function setCustomInstructions(instructions: string): void {
  KrithaModule.setCustomInstructions(instructions);
}

export function getUserName(): string {
  return KrithaModule.getUserName ? KrithaModule.getUserName() : 'Your Name';
}

export function setUserName(name: string): void {
  if (KrithaModule.setUserName) {
    KrithaModule.setUserName(name);
  }
}

export function getLocalModelDevice(): 'cpu' | 'gpu' {
  return KrithaModule.getLocalModelDevice();
}

export function setLocalModelDevice(device: 'cpu' | 'gpu'): 'cpu' | 'gpu' {
  return KrithaModule.setLocalModelDevice(device);
}

export function getAvailableModels(): ModelMetadata[] {
  return KrithaModule.getAvailableModels() || [];
}

export function getSelectedModel(): string {
  return KrithaModule.getSelectedModel() || '';
}

export function setSelectedModel(modelId: string): string {
  return KrithaModule.setSelectedModel(modelId);
}

export function isModelDownloaded(modelId: string): boolean {
  return KrithaModule.isModelDownloaded(modelId);
}

export function getDownloadedModels(): string[] {
  return KrithaModule.getDownloadedModels() || [];
}

export function downloadModel(modelId: string): void {
  KrithaModule.downloadModel(modelId);
}

export function pauseDownload(modelId: string): void {
  KrithaModule.pauseDownload(modelId);
}

export function resumeDownload(modelId: string): void {
  KrithaModule.resumeDownload(modelId);
}

export function cancelDownload(modelId: string): void {
  KrithaModule.cancelDownload(modelId);
}

export function isDefaultAssistant(): boolean {
  return KrithaModule.isDefaultAssistant();
}

export function openAssistantSettings(): boolean {
  return KrithaModule.openAssistantSettings();
}

export function isNotificationListenerEnabled(): boolean {
  return KrithaModule.isNotificationListenerEnabled
    ? KrithaModule.isNotificationListenerEnabled()
    : false;
}

export function requestNotificationListenerPermission(): boolean {
  return KrithaModule.requestNotificationListenerPermission
    ? KrithaModule.requestNotificationListenerPermission()
    : false;
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void,
): EventSubscription {
  return emitter.addListener('onWakeWordDetected', listener);
}

export function addAssistantListener(
  listener: (event: AssistantEvent) => void,
): EventSubscription {
  return emitter.addListener('onAssistantEvent', listener);
}

export function addDownloadProgressListener(
  listener: (event: DownloadProgressEvent) => void,
): EventSubscription {
  return emitter.addListener('onDownloadProgress', listener);
}

export {
  AssistantCommand,
  AssistantEvent,
  CanonicalAssistantState,
  DownloadProgressEvent,
  MicOwner,
  ModelMetadata,
  NativeChatSession,
  RequestOrigin,
  WakeWordEvent,
};
