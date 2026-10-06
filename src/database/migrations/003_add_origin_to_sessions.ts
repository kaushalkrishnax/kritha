import { DB } from '@op-engineering/op-sqlite';

export const migration003 = {
  version: 3,
  name: '003_add_origin_to_sessions',
  async up(db: DB): Promise<void> {
    try {
      await db.execute(`
        ALTER TABLE sessions ADD COLUMN origin TEXT;
      `);
    } catch (error) {
      console.warn(
        '[Migration] Column origin might already exist or another error occurred:',
        error,
      );
    }
  },
};
