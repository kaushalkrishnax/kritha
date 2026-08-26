import { ValidationError, VectorStoreError } from './errors';
import { DbProvider, QueryExecutor, VectorSearchResult } from './types';

export class VectorStore {
  constructor(private readonly provider: DbProvider) {}

  // Validates embedding dimension and numeric integrity.
  public validateEmbedding(embedding: number[], expectedDimension?: number): void {
    if (!Array.isArray(embedding) || embedding.length === 0) {
      throw new ValidationError('Embedding must be a non-empty array of numbers');
    }
    if (expectedDimension !== undefined && embedding.length !== expectedDimension) {
      throw new ValidationError(
        `Embedding dimension mismatch: expected ${expectedDimension}, got ${embedding.length}`
      );
    }
    for (let i = 0; i < embedding.length; i++) {
      if (typeof embedding[i] !== 'number' || !Number.isFinite(embedding[i])) {
        throw new ValidationError(`Invalid vector value at index ${i}: ${embedding[i]}`);
      }
    }
  }

  // Inserts an embedding for a tool into the sqlite-vec virtual table.
  async insert(
    toolId: string,
    embedding: number[],
    expectedDimension?: number,
    executor?: QueryExecutor
  ): Promise<void> {
    if (!toolId) {
      throw new ValidationError('Tool ID is required for vector insertion');
    }
    this.validateEmbedding(embedding, expectedDimension);

    const exec = executor ?? (await this.provider.getDbAsync());
    try {
      const jsonStr = JSON.stringify(embedding);
      await exec.execute(`DELETE FROM tool_vectors WHERE tool_id = ?`, [toolId]);
      await exec.execute(
        `INSERT INTO tool_vectors (tool_id, embedding) VALUES (?, vec_f32(?))`,
        [toolId, jsonStr]
      );
    } catch (error) {
      if (error instanceof ValidationError) throw error;
      throw new VectorStoreError(`Failed to insert vector for tool ID ${toolId}`, error);
    }
  }

  // Performs actual nearest-neighbor vector search using sqlite-vec MATCH syntax.
  async search(
    queryEmbedding: number[],
    limit: number = 5,
    expectedDimension?: number,
    executor?: QueryExecutor
  ): Promise<VectorSearchResult[]> {
    this.validateEmbedding(queryEmbedding, expectedDimension);
    if (limit <= 0) {
      throw new ValidationError('Top-K limit must be a positive integer');
    }

    const exec = executor ?? (await this.provider.getDbAsync());
    try {
      const jsonStr = JSON.stringify(queryEmbedding);
      const result = await exec.execute(
        `SELECT tool_id, distance FROM tool_vectors WHERE embedding MATCH vec_f32(?) AND k = ? ORDER BY distance`,
        [jsonStr, limit]
      );

      const rows = result.rows ?? [];
      return rows.map((row) => ({
        toolId: String(row.tool_id),
        distance: Number(row.distance),
      }));
    } catch (error) {
      if (error instanceof ValidationError) throw error;
      throw new VectorStoreError('Failed to execute sqlite-vec nearest neighbor search', error);
    }
  }

  // Updates an existing vector for a tool.
  async update(
    toolId: string,
    embedding: number[],
    expectedDimension?: number,
    executor?: QueryExecutor
  ): Promise<void> {
    await this.insert(toolId, embedding, expectedDimension, executor);
  }

  // Deletes a vector by toolId.
  async delete(toolId: string, executor?: QueryExecutor): Promise<void> {
    if (!toolId) {
      throw new ValidationError('Tool ID is required for vector deletion');
    }
    const exec = executor ?? (await this.provider.getDbAsync());
    try {
      await exec.execute(`DELETE FROM tool_vectors WHERE tool_id = ?`, [toolId]);
    } catch (error) {
      throw new VectorStoreError(`Failed to delete vector for tool ID ${toolId}`, error);
    }
  }

  // Retrieves a stored vector by toolId (if present).
  async get(toolId: string, executor?: QueryExecutor): Promise<number[] | null> {
    if (!toolId) return null;
    const exec = executor ?? (await this.provider.getDbAsync());
    try {
      const result = await exec.execute(
        `SELECT vec_to_json(embedding) as json_val FROM tool_vectors WHERE tool_id = ?`,
        [toolId]
      );
      const rows = result.rows ?? [];
      if (rows.length === 0 || !rows[0].json_val) return null;
      return JSON.parse(String(rows[0].json_val)) as number[];
    } catch (error) {
      return null;
    }
  }
}