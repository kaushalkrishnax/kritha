import { useEffect } from "react";

import { assistantService } from "@/services/assistant.service";

export function useAssistant() {
  useEffect(() => {
    void assistantService.start();

    return () => {
      // cleanup later
    };
  }, []);
}