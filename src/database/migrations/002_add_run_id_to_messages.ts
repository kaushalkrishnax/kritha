import { DB } from '@op-engineering/op-sqlite';

export const migration002 = {
  version: 2,
  name: '002_add_run_id_to_messages',
  async up(db: DB): Promise<void> {
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
