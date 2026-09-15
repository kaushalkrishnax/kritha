import { DB } from '@op-engineering/op-sqlite';

export const migration002 = {
  version: 2,
  name: '002_add_run_id_to_messages',
  async up(db: DB): Promise<void> {
    // SQLite doesn't natively support IF NOT EXISTS for columns in ALTER TABLE directly,
    // so we can wrap it in a try-catch to safely ignore if it already exists,
    // or just run it directly since it's a controlled migration.
    try {
      await db.execute(`
        ALTER TABLE messages ADD COLUMN run_id TEXT;
      `);
    } catch (error) {
      console.warn(
        '[Migration] Column run_id might already exist or another error occurred:',
        error,
      );
    }
  },
};
