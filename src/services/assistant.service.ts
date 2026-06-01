import { wakeWordService } from "./wakeword.service";

class AssistantService {
  private isProcessingCommand = false;

  public async startAssistantPipeline(): Promise<void> {
    console.log("Assistant initialization starting");
    
    await wakeWordService.start((keyword) => {
      this.handleWakeWordTrigger(keyword);
    });
  }

  public async stopAssistantPipeline(): Promise<void> {
    await wakeWordService.stop();
    this.isProcessingCommand = false;
    console.log("Assistant execution pipeline entirely shutdown");
  }

  private async handleWakeWordTrigger(keyword: string): Promise<void> {
    console.log(`Wake word detected by core hardware engine with keyword identifier ${keyword}`);

    if (this.isProcessingCommand) {
      return;
    }

    this.isProcessingCommand = true;

    // Temporarily stop local wake word detection so the microphone can be used for Speech to Text processing
    await wakeWordService.stop();

    this.startSpeechToTextFlow();
  }

  private startSpeechToTextFlow(): void {
    console.log("Wake word successfully verified. Opening speech pipeline for general user input");

    // This simulation represents where your user speech recording or transcription API calls happen
    setTimeout(async () => {
      console.log("User command processing finished. Resuming wake word background listening context");
      this.isProcessingCommand = false;
      
      // Turn background listening back on for continuous detection
      await wakeWordService.start((keyword) => {
        this.handleWakeWordTrigger(keyword);
      });
    }, 5000);
  }
}

export const assistantService = new AssistantService();