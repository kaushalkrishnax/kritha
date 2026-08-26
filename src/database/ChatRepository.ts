import { v4 as uuidv4 } from 'uuid';
import { DatabaseError, NotFoundError, ValidationError } from './errors';
import {
  CreateMessageInput,
  CreateSessionInput,
  DbProvider,
  Message,
  Session,
  UpdateSessionInput,
} from './types';

export class ChatRepository {
  constructor(private readonly provider: DbProvider) {}

  private mapSessionRow(row: Record<string, unknown>): Session {
    return {
      id: String(row.id),
      title: String(row.title),
      pinned: Boolean(row.pinned),
      archived: Boolean(row.archived),
      createdAt: Number(row.created_at),
      updatedAt: Number(row.updated_at),
    };
  }

  private mapMessageRow(row: Record<string, unknown>): Message {
    return {
      id: String(row.id),
      sessionId: String(row.session_id),
      role: row.role === 'user' ? 'user' : 'assistant',
      content: String(row.content),
      createdAt: Number(row.created_at),
      updatedAt: Number(row.updated_at),
    };
  }

  // Creates a new chat session.
  async createSession(titleOrInput: string | CreateSessionInput): Promise<Session> {
    const input: CreateSessionInput =
      typeof titleOrInput === 'string' ? { title: titleOrInput } : titleOrInput;

    const title = input.title ? input.title.trim() : 'New Chat';
    if (!title) {
      throw new ValidationError('Session title cannot be empty');
    }

    const sessionId = input.customId || uuidv4();
    const now = input.createdAt || Date.now();
    const pinned = input.pinned ? 1 : 0;
    const archived = input.archived ? 1 : 0;

    const session: Session = {
      id: sessionId,
      title,
      pinned: Boolean(pinned),
      archived: Boolean(archived),
      createdAt: now,
      updatedAt: now,
    };

    const db = await this.provider.getDbAsync();
    try {
      await db.execute(
        `INSERT INTO sessions (id, title, pinned, archived, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [session.id, session.title, pinned, archived, session.createdAt, session.updatedAt]
      );
      return session;
    } catch (error) {
      throw new DatabaseError(`Failed to create session '${title}'`, error);
    }
  }

  // Retrieves a chat session by ID.
  async getSession(id: string): Promise<Session | null> {
    if (!id) return null;
    const db = await this.provider.getDbAsync();
    try {
      const result = await db.execute(`SELECT * FROM sessions WHERE id = ?`, [id]);
      const rows = result.rows ?? [];
      if (rows.length === 0) return null;
      return this.mapSessionRow(rows[0]);
    } catch (error) {
      throw new DatabaseError(`Failed to get session ${id}`, error);
    }
  }

  // Gets sessions ordered by pinned status and updated_at desc.
  async getSessions(includeArchived: boolean = false): Promise<Session[]> {
    const db = await this.provider.getDbAsync();
    try {
      let query = `SELECT * FROM sessions WHERE archived = 0 ORDER BY pinned DESC, updated_at DESC`;
      if (includeArchived) {
        query = `SELECT * FROM sessions ORDER BY pinned DESC, updated_at DESC`;
      }
      const result = await db.execute(query);
      const rows = result.rows ?? [];
      return rows.map((row) => this.mapSessionRow(row));
    } catch (error) {
      throw new DatabaseError('Failed to fetch sessions', error);
    }
  }

  // Updates session properties (title, pinned, archived).
  async updateSession(id: string, input: UpdateSessionInput): Promise<Session> {
    const session = await this.getSession(id);
    if (!session) {
      throw new NotFoundError(`Session ${id} not found`);
    }

    const title = input.title !== undefined ? input.title.trim() : session.title;
    const pinned = input.pinned !== undefined ? (input.pinned ? 1 : 0) : (session.pinned ? 1 : 0);
    const archived = input.archived !== undefined ? (input.archived ? 1 : 0) : (session.archived ? 1 : 0);
    const now = Date.now();

    const db = await this.provider.getDbAsync();
    try {
      await db.execute(
        `UPDATE sessions SET title = ?, pinned = ?, archived = ?, updated_at = ? WHERE id = ?`,
        [title, pinned, archived, now, id]
      );
      return {
        id,
        title,
        pinned: Boolean(pinned),
        archived: Boolean(archived),
        createdAt: session.createdAt,
        updatedAt: now,
      };
    } catch (error) {
      throw new DatabaseError(`Failed to update session ${id}`, error);
    }
  }

  async updateSessionTitle(id: string, title: string): Promise<Session> {
    return this.updateSession(id, { title });
  }

  async pinSession(id: string, pinned: boolean): Promise<Session> {
    return this.updateSession(id, { pinned });
  }

  async archiveSession(id: string, archived: boolean): Promise<Session> {
    return this.updateSession(id, { archived });
  }

  // Deletes a session and its cascading messages.
  async deleteSession(id: string): Promise<void> {
    const db = await this.provider.getDbAsync();
    try {
      await db.execute(`DELETE FROM sessions WHERE id = ?`, [id]);
    } catch (error) {
      throw new DatabaseError(`Failed to delete session ${id}`, error);
    }
  }

  // Saves a message in a session. Updates session updated_at timestamp.
  async saveMessage(
    sessionIdOrInput: string | CreateMessageInput,
    role?: 'user' | 'assistant',
    content?: string,
    customId?: string,
    createdAt?: number
  ): Promise<Message> {
    let input: CreateMessageInput;

    if (typeof sessionIdOrInput === 'string') {
      if (!role || content === undefined) {
        throw new ValidationError('Role and content are required when passing individual parameters');
      }
      input = {
        sessionId: sessionIdOrInput,
        role,
        content,
        customId,
        createdAt,
      };
    } else {
      input = sessionIdOrInput;
    }

    if (!input.sessionId) {
      throw new ValidationError('Message sessionId is required');
    }
    if (input.role !== 'user' && input.role !== 'assistant') {
      throw new ValidationError(`Invalid message role: '${input.role}'`);
    }

    const messageId = input.customId || uuidv4();
    const now = input.createdAt || Date.now();

    const message: Message = {
      id: messageId,
      sessionId: input.sessionId,
      role: input.role,
      content: input.content,
      createdAt: now,
      updatedAt: now,
    };

    const db = await this.provider.getDbAsync();
    try {
      await db.transaction(async (tx) => {
        // Ensure session exists or touch updated_at
        const sessRes = await tx.execute(`SELECT id FROM sessions WHERE id = ?`, [input.sessionId]);
        if ((sessRes.rows ?? []).length === 0) {
          const autoTitle =
            input.content.length > 25 ? `${input.content.slice(0, 25)}...` : input.content || 'New Chat';
          await tx.execute(
            `INSERT INTO sessions (id, title, pinned, archived, created_at, updated_at) VALUES (?, ?, 0, 0, ?, ?)`,
            [input.sessionId, autoTitle, now, now]
          );
        } else {
          await tx.execute(`UPDATE sessions SET updated_at = ? WHERE id = ?`, [now, input.sessionId]);
        }

        await tx.execute(
          `INSERT INTO messages (id, session_id, role, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)`,
          [message.id, message.sessionId, message.role, message.content, message.createdAt, message.updatedAt]
        );
      });

      return message;
    } catch (error) {
      if (error instanceof ValidationError) throw error;
      throw new DatabaseError(`Failed to save message in session ${input.sessionId}`, error);
    }
  }

  // Retrieves messages for a session in chronological order (created_at ASC).
  async getMessages(sessionId: string): Promise<Message[]> {
    if (!sessionId) return [];
    const db = await this.provider.getDbAsync();
    try {
      const result = await db.execute(
        `SELECT * FROM messages WHERE session_id = ? ORDER BY created_at ASC`,
        [sessionId]
      );
      const rows = result.rows ?? [];
      return rows.map((row) => this.mapMessageRow(row));
    } catch (error) {
      throw new DatabaseError(`Failed to fetch messages for session ${sessionId}`, error);
    }
  }

  // Retrieves recent messages for context building (up to limit).
  async getHistory(sessionId: string, limit: number = 20): Promise<Message[]> {
    if (!sessionId) return [];
    const db = await this.provider.getDbAsync();
    try {
      const result = await db.execute(
        `SELECT * FROM (
          SELECT * FROM messages WHERE session_id = ? ORDER BY created_at DESC LIMIT ?
         ) ORDER BY created_at ASC`,
        [sessionId, limit]
      );
      const rows = result.rows ?? [];
      return rows.map((row) => this.mapMessageRow(row));
    } catch (error) {
      throw new DatabaseError(`Failed to fetch history for session ${sessionId}`, error);
    }
  }

  // Deletes all messages in a session.
  async deleteMessages(sessionId: string): Promise<void> {
    if (!sessionId) return;
    const db = await this.provider.getDbAsync();
    try {
      await db.execute(`DELETE FROM messages WHERE session_id = ?`, [sessionId]);
    } catch (error) {
      throw new DatabaseError(`Failed to delete messages for session ${sessionId}`, error);
    }
  }
}