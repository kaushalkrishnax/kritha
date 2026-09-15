import { DB, open } from '@op-engineering/op-sqlite';
import { ChatRepository } from './ChatRepository';
import { DatabaseError, MigrationError } from './errors';
import { migration001 } from './migrations/001_init';
import { migration002 } from './migrations/002_add_run_id_to_messages';
import { ToolRepository } from './ToolRepository';
import { DbProvider } from './types';
import { VectorStore } from './VectorStore';

export class Database {
  private static instance: Database | null = null;
  private db: DB | null = null;
  private initPromise: Promise<void> | null = null;
  private initialized: boolean = false;

  public readonly sessions: ChatRepository;
  public readonly messages: ChatRepository;
  public readonly vectors: VectorStore;
  public readonly tools: ToolRepository;

  private constructor() {
    const provider: DbProvider = this;
    this.sessions = new ChatRepository(provider);
    this.messages = this.sessions;
    this.vectors = new VectorStore(provider);
    this.tools = new ToolRepository(this.vectors, provider);
  }

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  async init(): Promise<void> {
    if (this.initialized && this.db) {
      return;
    }
    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = (async () => {
      try {
        this.db = open({
          name: 'kritha.sqlite',
        });

        await this.db.execute('PRAGMA foreign_keys = ON;');
        await this.db.execute('PRAGMA journal_mode = WAL;');

        // Run versioned migrations
        await this.runMigrations();

        this.initialized = true;
        console.log(
          '[Database] Initialized successfully with sqlite-vec and foreign keys enabled',
        );
      } catch (error) {
        this.db = null;
        this.initialized = false;
        console.error('[Database] Critical initialization error:', error);
        throw new DatabaseError('Failed to initialize local database', error);
      } finally {
        this.initPromise = null;
      }
    })();

    return this.initPromise;
  }

  private async runMigrations(): Promise<void> {
    if (!this.db) {
      throw new DatabaseError('Database connection not established');
    }

    try {
      const versionResult = await this.db.execute('PRAGMA user_version;');
      const currentVersion = Number(versionResult.rows?.[0]?.user_version ?? 0);
      const migrations = [migration001, migration002];

      for (const migration of migrations) {
        if (currentVersion < migration.version) {
          console.log(
            `[Database] Applying migration v${migration.version}: ${migration.name}`,
          );
          await migration.up(this.db);
          await this.db.execute(`PRAGMA user_version = ${migration.version};`);
        }
      }
    } catch (error) {
      throw new MigrationError('Failed to execute schema migrations', error);
    }
  }

  // Waits for initialization to complete, then returns the connection.
  whenReady(): Promise<void> {
    if (this.initialized && this.db) {
      return Promise.resolve();
    }
    if (!this.initPromise) {
      void this.init().catch(() => {});
    }
    return this.initPromise ?? Promise.resolve();
  }

  async getDbAsync(): Promise<DB> {
    await this.whenReady();
    return this.getDb();
  }

  getDb(): DB {
    if (!this.db || !this.initialized) {
      throw new DatabaseError(
        'Database is not initialized. Call database.init() first.',
      );
    }
    return this.db;
  }

  isInitialized(): boolean {
    return this.initialized && this.db !== null;
  }

  async close(): Promise<void> {
    if (this.db) {
      try {
        this.db.close();
        this.db = null;
        this.initialized = false;
        console.log('[Database] Database closed');
      } catch (error) {
        console.error('[Database] Failed to close database cleanly:', error);
      }
    }
  }
}

const database = Database.getInstance();
export default database;
