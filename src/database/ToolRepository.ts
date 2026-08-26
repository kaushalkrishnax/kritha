import { v4 as uuidv4 } from 'uuid';
import { VectorStore } from './VectorStore';
import {
  CreateToolInput,
  DbProvider,
  JsonObject,
  ToolDefinition,
  UpdateToolInput,
  VectorSearchResult,
} from './types';
import { DatabaseError, NotFoundError, ValidationError } from './errors';

export class ToolRepository {
  private vectorStore: VectorStore;
  private provider: DbProvider;

  constructor(vectorStore: VectorStore, provider: DbProvider) {
    this.vectorStore = vectorStore;
    this.provider = provider;
  }

  private serializeJson(value: unknown): string {
    return JSON.stringify(value ?? {});
  }

  private deserializeJson<T>(jsonStr: string, defaultValue: T): T {
    if (!jsonStr) return defaultValue;
    try {
      return JSON.parse(jsonStr) as T;
    } catch {
      return defaultValue;
    }
  }

  private mapToolRow(row: Record<string, unknown>): ToolDefinition {
    return {
      id: String(row.id),
      name: String(row.name),
      description: String(row.description),
      examples: this.deserializeJson<string[]>(String(row.examples), []),
      parameters: this.deserializeJson<JsonObject>(String(row.parameters), {}),
      permissions: this.deserializeJson<string[]>(String(row.permissions), []),
      category: String(row.category),
      source: String(row.source),
      createdAt: Number(row.created_at),
      updatedAt: Number(row.updated_at),
      embeddingModel: String(row.embedding_model),
      embeddingDimension: Number(row.embedding_dimension),
      metadata: this.deserializeJson<JsonObject>(String(row.metadata), {}),
    };
  }

//  Creates a new tool definition and optionally inserts its vector embedding atomically.
async createTool(input: CreateToolInput): Promise<ToolDefinition> {
  if (!input.name || input.name.trim() === '') {
    throw new ValidationError('Tool name is required');
  }
  if (!input.description) {
    throw new ValidationError('Tool description is required');
  }
  if (!input.embeddingModel || input.embeddingDimension <= 0) {
    throw new ValidationError('Valid embeddingModel and positive embeddingDimension are required');
  }

  if (input.embedding) {
    this.vectorStore.validateEmbedding(input.embedding, input.embeddingDimension);
  }

  const toolId = uuidv4();
  const now = Date.now();

  const tool: ToolDefinition = {
    id: toolId,
    name: input.name.trim(),
    description: input.description,
    examples: input.examples ?? [],
    parameters: input.parameters ?? {},
    permissions: input.permissions ?? [],
    category: input.category,
    source: input.source ?? 'custom',
    createdAt: now,
    updatedAt: now,
    embeddingModel: input.embeddingModel,
    embeddingDimension: input.embeddingDimension,
    metadata: input.metadata ?? {},
  };

  const db = await this.provider.getDbAsync();
  try {
    await db.transaction(async (tx) => {
      await tx.execute(
        `INSERT INTO tools (
          id, name, description, examples, parameters, permissions,
          category, source, created_at, updated_at, embedding_model,
          embedding_dimension, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          tool.id,
          tool.name,
          tool.description,
          this.serializeJson(tool.examples),
          this.serializeJson(tool.parameters),
          this.serializeJson(tool.permissions),
          tool.category,
          tool.source,
          tool.createdAt,
          tool.updatedAt,
          tool.embeddingModel,
          tool.embeddingDimension,
          this.serializeJson(tool.metadata),
        ]
      );

      if (input.embedding) {
        await this.vectorStore.insert(tool.id, input.embedding, tool.embeddingDimension, tx);
      }
    });

    return tool;
  } catch (error) {
    if (error instanceof ValidationError) throw error;
    throw new DatabaseError(`Failed to create tool '${input.name}'`, error);
  }
}

// Retrieves a tool by ID.
async getTool(id: string): Promise<ToolDefinition | null> {
  if (!id) return null;
  const db = await this.provider.getDbAsync();
  try {
    const result = await db.execute(`SELECT * FROM tools WHERE id = ?`, [id]);
    const rows = result.rows ?? [];
    if (rows.length === 0) return null;
    return this.mapToolRow(rows[0]);
  } catch (error) {
    throw new DatabaseError(`Failed to fetch tool with ID ${id}`, error);
  }
}

// Retrieves a tool by name.
async getToolByName(name: string): Promise<ToolDefinition | null> {
  if (!name) return null;
  const db = await this.provider.getDbAsync();
  try {
    const result = await db.execute(`SELECT * FROM tools WHERE name = ?`, [name]);
    const rows = result.rows ?? [];
    if (rows.length === 0) return null;
    return this.mapToolRow(rows[0]);
  } catch (error) {
    throw new DatabaseError(`Failed to fetch tool with name ${name}`, error);
  }
}

// Retrieves all tools, optionally filtered by category.
async getTools(category?: string): Promise<ToolDefinition[]> {
  const db = await this.provider.getDbAsync();
  try {
    let query = `SELECT * FROM tools ORDER BY name ASC`;
    const params: string[] = [];
    if (category) {
      query = `SELECT * FROM tools WHERE category = ? ORDER BY name ASC`;
      params.push(category);
    }
    const result = await db.execute(query, params);
    const rows = result.rows ?? [];
    return rows.map((row) => this.mapToolRow(row));
  } catch (error) {
    throw new DatabaseError('Failed to fetch tools', error);
  }
}

// Updates an existing tool and/or its vector embedding inside an atomic transaction.
async updateTool(id: string, input: UpdateToolInput): Promise<ToolDefinition> {
  const existing = await this.getTool(id);
  if (!existing) {
    throw new NotFoundError(`Tool with ID ${id} not found`);
  }

  const newDimension = input.embeddingDimension ?? existing.embeddingDimension;
  const newModel = input.embeddingModel ?? existing.embeddingModel;

  if (
    (newDimension !== existing.embeddingDimension || newModel !== existing.embeddingModel) &&
    !input.embedding
  ) {
    throw new ValidationError(
      `Changing embeddingModel or embeddingDimension requires passing a new embedding vector`
    );
  }

  if (input.embedding) {
    this.vectorStore.validateEmbedding(input.embedding, newDimension);
  }

  const now = Date.now();
  const updatedTool: ToolDefinition = {
    ...existing,
    name: input.name ? input.name.trim() : existing.name,
    description: input.description ?? existing.description,
    examples: input.examples ?? existing.examples,
    parameters: input.parameters ?? existing.parameters,
    permissions: input.permissions ?? existing.permissions,
    category: input.category ?? existing.category,
    source: input.source ?? existing.source,
    embeddingModel: newModel,
    embeddingDimension: newDimension,
    metadata: input.metadata ?? existing.metadata,
    updatedAt: now,
  };

  const db = await this.provider.getDbAsync();
  try {
    await db.transaction(async (tx) => {
      await tx.execute(
        `UPDATE tools SET
          name = ?, description = ?, examples = ?, parameters = ?, permissions = ?,
          category = ?, source = ?, updated_at = ?, embedding_model = ?,
          embedding_dimension = ?, metadata = ?
        WHERE id = ?`,
        [
          updatedTool.name,
          updatedTool.description,
          this.serializeJson(updatedTool.examples),
          this.serializeJson(updatedTool.parameters),
          this.serializeJson(updatedTool.permissions),
          updatedTool.category,
          updatedTool.source,
          updatedTool.updatedAt,
          updatedTool.embeddingModel,
          updatedTool.embeddingDimension,
          this.serializeJson(updatedTool.metadata),
          id,
        ]
      );

      if (input.embedding) {
        await this.vectorStore.update(id, input.embedding, newDimension, tx);
      }
    });

    return updatedTool;
  } catch (error) {
    if (error instanceof ValidationError || error instanceof NotFoundError) throw error;
    throw new DatabaseError(`Failed to update tool ${id}`, error);
  }
}

// Deletes a tool and its associated vector embedding atomically.
async deleteTool(id: string): Promise<void> {
  const existing = await this.getTool(id);
  if (!existing) return;

  const db = await this.provider.getDbAsync();
  try {
    await db.transaction(async (tx) => {
      await tx.execute(`DELETE FROM tools WHERE id = ?`, [id]);
      await this.vectorStore.delete(id, tx);
    });
  } catch (error) {
    throw new DatabaseError(`Failed to delete tool ${id}`, error);
  }
}

// Searches for nearest tools by query vector. Returns matches along with their ToolDefinition metadata.
async searchTools(
  queryEmbedding: number[],
  limit: number = 5,
  expectedDimension?: number
): Promise<Array<VectorSearchResult & { tool: ToolDefinition }>> {
  const vectorResults = await this.vectorStore.search(queryEmbedding, limit, expectedDimension);
  if (vectorResults.length === 0) return [];

  const results: Array<VectorSearchResult & { tool: ToolDefinition }> = [];
  for (const item of vectorResults) {
    const tool = await this.getTool(item.toolId);
    if (tool) {
      results.push({
        toolId: item.toolId,
        distance: item.distance,
        tool,
      });
    }
  }
  return results;
}
}