import { EventSubscription } from 'expo-modules-core';

import {
  addAssistantListener,
  addWakeWordListener,
  AssistantEvent,
  cancel,
  dismiss,
  isRunning,
  start,
  stop,
} from '@modules/kritha/src';

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
    cancel();
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
  public respondToAssistant(_response: string): void {
    dismiss();
  }
}

export const wakeWordService = new WakeWordService();
