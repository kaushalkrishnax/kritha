export type ChatMessage = {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  sessionId?: string | null;
  createdAt?: number;
  status?: 'sending' | 'sent' | 'failed';
  variants?: { index: number; total: number };
};
