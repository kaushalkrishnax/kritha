const GEMINI_API_KEY =
  process.env.EXPO_PUBLIC_GEMINI_API_KEY || '';

const GEMINI_ENDPOINT =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

export class CloudService {
  private apiKey = GEMINI_API_KEY;

  public setApiKey(key: string) {
    this.apiKey = key;
  }

  public async generateStreamingResponse(
    messages: any[],
    onChunk: (chunk: string) => void
  ): Promise<string> {
    const prompt =
      messages[messages.length - 1]?.text || '';

    if (!prompt.trim()) {
      throw new Error(
        '[CloudService] Cannot generate a response from an empty prompt.'
      );
    }

    if (!this.apiKey) {
      throw new Error(
        '[CloudService] Gemini API key is not configured.'
      );
    }

    try {
      const response = await fetch(
        `${GEMINI_ENDPOINT}?key=${this.apiKey}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: prompt,
                  },
                ],
              },
            ],
          }),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();

        throw new Error(
          `Cloud LLM returned HTTP ${response.status}: ${errorText}`
        );
      }

      const data = await response.json();

      const text =
        data.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!text) {
        throw new Error(
          '[CloudService] Gemini returned an empty response.'
        );
      }

      const content = text.trim();

      onChunk(content);

      return content;
    } catch (error) {
      console.error(
        '[CloudService] Error fetching from Gemini API:',
        error
      );

      throw error;
    }
  }

  public async generateResponse(
    prompt: string
  ): Promise<string> {
    console.log(
      `[CloudService] Querying RAM (Cloud LLM) for: "${prompt}"`
    );

    if (!prompt.trim()) {
      throw new Error(
        '[CloudService] Cannot generate a response from an empty prompt.'
      );
    }

    if (!this.apiKey) {
      throw new Error(
        '[CloudService] Gemini API key is not configured.'
      );
    }

    try {
      const response = await fetch(
        `${GEMINI_ENDPOINT}?key=${this.apiKey}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: prompt,
                  },
                ],
              },
            ],
          }),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();

        throw new Error(
          `Cloud LLM returned HTTP ${response.status}: ${errorText}`
        );
      }

      const data = await response.json();

      const text =
        data.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!text) {
        throw new Error(
          '[CloudService] Gemini returned an empty response.'
        );
      }

      return text.trim();
    } catch (error) {
      console.error(
        '[CloudService] Error fetching from Gemini API:',
        error
      );

      throw error;
    }
  }
}

export const cloudService = new CloudService();