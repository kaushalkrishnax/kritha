import { wakeWordService } from "./wakeword.service";

class AssistantService {
  private unsubscribeFromAssistant?: () => void;

  public async startAssistantPipeline(): Promise<void> {
    this.unsubscribeFromAssistant?.();
    this.unsubscribeFromAssistant = wakeWordService.subscribeToAssistant((event) => {
      console.log("Native assistant event (for UI):", event);
    });
    await wakeWordService.start();
  }

  public async stopAssistantPipeline(): Promise<void> {
    this.unsubscribeFromAssistant?.();
    this.unsubscribeFromAssistant = undefined;
    await wakeWordService.stop();
    console.log("Assistant execution pipeline entirely shutdown");
  }
}

export const assistantService = new AssistantService();
