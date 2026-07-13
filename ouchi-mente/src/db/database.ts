import * as SQLite from "expo-sqlite";

let db: SQLite.SQLiteDatabase | null = null;

export function getDatabase(): SQLite.SQLiteDatabase {
  if (!db) {
    db = SQLite.openDatabaseSync("ouchi-mente.db");
  }
  return db;
}

const SCHEMA_VERSION = 1;

/** アプリ起動時に一度だけ呼ぶ。冪等。 */
export async function migrateDatabase(): Promise<void> {
  const database = getDatabase();
  await database.execAsync("PRAGMA journal_mode = WAL;");
  await database.execAsync("PRAGMA foreign_keys = ON;");

  const row = await database.getFirstAsync<{ user_version: number }>(
    "PRAGMA user_version;",
  );
  const currentVersion = row?.user_version ?? 0;
  if (currentVersion >= SCHEMA_VERSION) return;

  if (currentVersion < 1) {
    await database.execAsync(`
      CREATE TABLE IF NOT EXISTS maintenance_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        task_type TEXT NOT NULL,
        location TEXT,
        manufacturer TEXT,
        model_number TEXT,
        note TEXT,
        image_uri TEXT,
        schedule_type TEXT NOT NULL DEFAULT 'none',
        interval_value INTEGER,
        interval_unit TEXT,
        next_due_date TEXT,
        notification_enabled INTEGER NOT NULL DEFAULT 0,
        notification_timing_days INTEGER,
        notification_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      );

      CREATE TABLE IF NOT EXISTS maintenance_history (
        id TEXT PRIMARY KEY,
        maintenance_item_id TEXT NOT NULL
          REFERENCES maintenance_items(id) ON DELETE CASCADE,
        completed_at TEXT NOT NULL,
        note TEXT,
        image_uri TEXT,
        calculated_next_due_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_history_item
        ON maintenance_history(maintenance_item_id);
      CREATE INDEX IF NOT EXISTS idx_items_next_due
        ON maintenance_items(next_due_date);

      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    `);
  }

  await database.execAsync(`PRAGMA user_version = ${SCHEMA_VERSION};`);
}

/** 設定画面の「データ全削除」用 */
export async function deleteAllData(): Promise<void> {
  const database = getDatabase();
  await database.execAsync(`
    DELETE FROM maintenance_history;
    DELETE FROM maintenance_items;
    DELETE FROM app_settings;
  `);
}
