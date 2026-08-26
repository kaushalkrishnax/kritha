import { DB } from '@op-engineering/op-sqlite';

export const migration001 = {
  version: 1,
  name: '001_init',
  async up(db: DB): Promise<void> {
    await db.execute('PRAGMA foreign_keys = ON;');

    await db.execute(`
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);

    await db.execute(`
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      );
    `);

    await db.execute(`
      CREATE INDEX IF NOT EXISTS idx_messages_session_created ON messages(session_id, created_at);
    `);

    await db.execute(`
      CREATE INDEX IF NOT EXISTS idx_sessions_pinned_updated ON sessions(pinned, updated_at);
    `);

    await db.execute(`
      CREATE TABLE IF NOT EXISTS tools (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL,
        examples TEXT NOT NULL,
        parameters TEXT NOT NULL,
        permissions TEXT NOT NULL,
        category TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        embedding_model TEXT NOT NULL,
        embedding_dimension INTEGER NOT NULL,
        metadata TEXT NOT NULL
      );
    `);

    await db.execute(`
      CREATE INDEX IF NOT EXISTS idx_tools_category ON tools(category);
    `);

    await db.execute(`
      CREATE VIRTUAL TABLE IF NOT EXISTS tool_vectors USING vec0(
        tool_id TEXT PRIMARY KEY,
        embedding FLOAT[300]
      );
    `);
  },
};
