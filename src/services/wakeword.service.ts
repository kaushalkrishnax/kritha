import { start, stop, addWakeWordListener } from "../../modules/wakeword/src";
import { EventSubscription } from "expo-modules-core";

export class WakeWordService {
  private subscription: EventSubscription | null = null;
  private isRunning = false;

  public async start(onDetected: (keyword: string, confidence?: number) => void): Promise<void> {
    if (this.isRunning) return;

    this.subscription = addWakeWordListener((event) => {
      onDetected(event.keyword, event.confidence);
    });

    start();
    this.isRunning = true;
  }

  public async stop(): Promise<void> {
    if (!this.isRunning) return;

    stop();
    this.subscription?.remove();
    this.subscription = null;
    this.isRunning = false;
  }
}

export const wakeWordService = new WakeWordService();