import {
  getCustomInstructions,
  getUserName as getNativeUserName,
} from '@modules/kritha/src';
import { useAssistantStore } from '@/store/assistantStore';

export type ContextMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string;
};

export function buildKrithaSystemPrompt(userName: string): string {
  const name = (userName || '').trim();
  const nameClause =
    name && name.toLowerCase() !== 'your name'
      ? ` You are speaking with ${name}.`
      : '';

  return `You are Kritha, an intelligent personal AI assistant.${nameClause}

Be helpful, accurate, concise, and natural. Understand the user's intent and context before responding. Follow instructions carefully, remember relevant conversation context, and never fabricate facts, actions, or results.

Give direct, practical answers. Ask for clarification only when genuinely necessary. Correct mistakes honestly instead of agreeing blindly. Adapt your tone to the situation and avoid unnecessary repetition, filler, or excessive explanations.`.trim();
}

export type ConversationContextInput = {
  messages?: ReadonlyArray<{ role: 'user' | 'assistant'; text: string }>;
  userName?: string;
  customInstructions?: string;
  maxHistory?: number;
  includeSystem?: boolean;
};

export function buildConversationContext({
  messages = [],
  userName = '',
  customInstructions,
  maxHistory = 40,
  includeSystem = true,
}: ConversationContextInput = {}): ContextMessage[] {
  const context: ContextMessage[] = [];

  if (includeSystem) {
    context.push({ role: 'system', content: buildKrithaSystemPrompt(userName) });
    const custom = (customInstructions || '').trim();
    if (custom) {
      context.push({ role: 'system', content: custom });
    }
  }

  const recentHistory = messages.slice(-maxHistory);
  for (const msg of recentHistory) {
    const text = (msg.text || '').trim();
    if (!text) continue;
    context.push({
      role: msg.role === 'assistant' ? 'assistant' : 'user',
      content: text,
    });
  }

  return context;
}

export function getConversationContext(): ContextMessage[] {
  const store = useAssistantStore.getState();

  let userName = store.userName || '';
  let customInstructions = '';

  customInstructions = getCustomInstructions();
  const nativeName = getNativeUserName();
  if (nativeName) userName = userName || nativeName;

  return buildConversationContext({
    messages: store.messages,
    userName,
    customInstructions,
  });
}