import * as SQLite from 'expo-sqlite';

export interface ChatSession {
  id: string;
  title: string;
  created_at: number;
}

export interface ChatMessage {
  id: string;
  session_id: string;
  role: 'user' | 'assistant';
  text: string;
  created_at: number;
}

export class DBService {
  private db: SQLite.SQLiteDatabase;

  constructor() {
    this.db = SQLite.openDatabaseSync('kritha.db');
    this.init();
  }

  private init() {
    this.db.execSync(`
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      );
    `);
  }

  public getSessions(): ChatSession[] {
    return this.db.getAllSync<ChatSession>(
      'SELECT * FROM sessions ORDER BY created_at DESC',
    );
  }

  public createSession(title: string): ChatSession {
    const session: ChatSession = {
      id: Date.now().toString(),
      title,
      created_at: Date.now(),
    };
    this.db.runSync(
      'INSERT INTO sessions (id, title, created_at) VALUES (?, ?, ?)',
      [session.id, session.title, session.created_at],
    );
    return session;
  }

  public deleteSession(id: string) {
    this.db.runSync('DELETE FROM sessions WHERE id = ?', [id]);
  }

  public updateSessionTitle(id: string, title: string) {
    this.db.runSync('UPDATE sessions SET title = ? WHERE id = ?', [title, id]);
  }

  public getMessages(sessionId: string): ChatMessage[] {
    return this.db.getAllSync<ChatMessage>(
      'SELECT * FROM messages WHERE session_id = ? ORDER BY created_at ASC',
      [sessionId],
    );
  }

  public addMessage(message: ChatMessage) {
    this.db.runSync(
      'INSERT INTO messages (id, session_id, role, text, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        message.id,
        message.session_id,
        message.role,
        message.text,
        message.created_at,
      ],
    );
  }

  public updateMessage(id: string, text: string) {
    this.db.runSync('UPDATE messages SET text = ? WHERE id = ?', [text, id]);
  }
}

export const dbService = new DBService();
