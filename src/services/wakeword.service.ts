import { EventSubscription } from "expo-modules-core";

import {
  addAssistantListener,
  addWakeWordListener,
  AssistantEvent,
  isRunning,
  start,
  stop,
  stopAssistantSession,
  dispatchMediaKey,
  respondToAssistant,
  toggleFlashlight,
  getVolume,
  setVolume,
  getBatteryStatus,
  setWifi,
  setBluetooth,
  setAlarm,
  setTimer,
  openApp,
  callContact,
  sendSMS,
  isNotificationListenerEnabled,
  requestNotificationListenerPermission,
  readNotifications,
  getCalendarEvents,
} from "../../modules/wakeword/src";

type DetectionListener = (keyword: string, confidence?: number) => void;
type AssistantListener = (event: AssistantEvent) => void;

export class WakeWordService {
  private subscription: EventSubscription | null = null;
  private assistantSubscription: EventSubscription | null = null;
  private listeners = new Set<DetectionListener>();
  private assistantListeners = new Set<AssistantListener>();

  public async start(onDetected?: DetectionListener): Promise<void> {
    if (onDetected) this.listeners.add(onDetected);
    this.ensureNativeSubscription();
    if (!isRunning()) start();
  }

  public async stop(): Promise<void> {
    if (isRunning()) stop();
  }

  public async stopAssistantSession(): Promise<void> {
    stopAssistantSession();
  }

  public getIsRunning(): boolean {
    return isRunning();
  }

  public subscribe(listener: DetectionListener): () => void {
    this.listeners.add(listener);
    this.ensureNativeSubscription();

    return () => {
      this.listeners.delete(listener);
      if (this.listeners.size === 0) {
        this.subscription?.remove();
        this.subscription = null;
      }
    };
  }

  public subscribeToAssistant(listener: AssistantListener): () => void {
    this.assistantListeners.add(listener);
    this.ensureAssistantSubscription();

    return () => {
      this.assistantListeners.delete(listener);
      if (this.assistantListeners.size === 0) {
        this.assistantSubscription?.remove();
        this.assistantSubscription = null;
      }
    };
  }

  private ensureNativeSubscription(): void {
    if (this.subscription) return;
    this.subscription = addWakeWordListener((event) => {
      this.listeners.forEach((listener) => {
        listener(event.keyword, event.confidence);
      });
    });
  }

  private ensureAssistantSubscription(): void {
    if (this.assistantSubscription) return;
    this.assistantSubscription = addAssistantListener((event) => {
      this.assistantListeners.forEach((listener) => {
        listener(event);
      });
    });
  }

  // Native Command Wrappers
  public respondToAssistant(response: string): void {
    respondToAssistant(response);
  }

  public dispatchMediaKey(keyCode: number): void {
    dispatchMediaKey(keyCode);
  }

  public toggleFlashlight(enable: boolean): void {
    toggleFlashlight(enable);
  }

  public getVolume(): number {
    return getVolume();
  }

  public setVolume(level: number): void {
    setVolume(level);
  }

  public getBatteryStatus(): { level: number; isCharging: boolean } {
    return getBatteryStatus();
  }

  public setWifi(enable: boolean): void {
    setWifi(enable);
  }

  public setBluetooth(enable: boolean): void {
    setBluetooth(enable);
  }

  public setAlarm(hour: number, minute: number, message: string): void {
    setAlarm(hour, minute, message);
  }

  public setTimer(durationSeconds: number, message: string): void {
    setTimer(durationSeconds, message);
  }

  public openApp(appName: string): boolean {
    return openApp(appName);
  }

  public callContact(contactName: string): { success: boolean; resolvedName: string } {
    return callContact(contactName);
  }

  public sendSMS(contactName: string, message: string): { success: boolean; resolvedName: string } {
    return sendSMS(contactName, message);
  }

  public isNotificationListenerEnabled(): boolean {
    return isNotificationListenerEnabled();
  }

  public requestNotificationListenerPermission(): void {
    requestNotificationListenerPermission();
  }

  public readNotifications(): Array<{ packageName: string; title: string; text: string }> {
    return readNotifications();
  }

  public getCalendarEvents(): Array<{ title: string; startTime: number; description: string }> {
    return getCalendarEvents();
  }
}

export const wakeWordService = new WakeWordService();
