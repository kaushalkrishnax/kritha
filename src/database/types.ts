import type { DB } from '@op-engineering/op-sqlite';

export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };
export type JsonObject = { [key: string]: unknown };

export interface Session {
  id: string;
  title: string;
  pinned: boolean;
  archived: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface CreateSessionInput {
  title: string;
  pinned?: boolean;
  archived?: boolean;
  customId?: string;
  createdAt?: number;
}

export interface UpdateSessionInput {
  title?: string;
  pinned?: boolean;
  archived?: boolean;
}

export interface Message {
  id: string;
  sessionId: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: number;
  updatedAt: number;
}

export interface CreateMessageInput {
  sessionId: string;
  role: 'user' | 'assistant';
  content: string;
  customId?: string;
  createdAt?: number;
}

export type ToolSource = 'native' | 'custom' | 'extension' | (string & {});

export interface ToolDefinition {
  id: string;
  name: string;
  description: string;
  examples: string[];
  parameters: JsonObject;
  permissions: string[];
  category: string;
  source: ToolSource;
  createdAt: number;
  updatedAt: number;
  embeddingModel: string;
  embeddingDimension: number;
  metadata: JsonObject;
}

export interface CreateToolInput {
  name: string;
  description: string;
  examples?: string[];
  parameters?: JsonObject;
  permissions?: string[];
  category: string;
  source?: ToolSource;
  embeddingModel: string;
  embeddingDimension: number;
  metadata?: JsonObject;
  embedding?: number[];
}

export interface UpdateToolInput {
  name?: string;
  description?: string;
  examples?: string[];
  parameters?: JsonObject;
  permissions?: string[];
  category?: string;
  source?: ToolSource;
  embeddingModel?: string;
  embeddingDimension?: number;
  metadata?: JsonObject;
  embedding?: number[];
}

export interface ToolEmbedding {
  toolId: string;
  embedding: number[];
}

export interface VectorSearchResult {
  toolId: string;
  distance: number;
}

export interface QueryExecutor {
  execute(query: string, params?: (string | number | null | Uint8Array)[]): Promise<{
    rows?: Record<string, unknown>[];
    rowsAffected?: number;
    insertId?: number;
  }>;
}

/**
 * Async accessor for the underlying database connection. Implemented by the
 * Database singleton and injected into repositories, keeping the module
 * dependency graph acyclic.
 */
export interface DbProvider {
  /** Waits until initialization completes, then returns the connection. */
  getDbAsync(): Promise<DB>;
}
