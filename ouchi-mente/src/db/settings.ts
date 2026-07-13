import { getDatabase } from "./database";

export type AppSettingKey =
  | "onboardingCompleted"
  | "defaultNotificationEnabled"
  | "defaultNotificationTimingDays"
  | "plusUnlocked";

export async function getSetting(key: AppSettingKey): Promise<string | null> {
  const row = await getDatabase().getFirstAsync<{ value: string }>(
    "SELECT value FROM app_settings WHERE key = ?;",
    [key],
  );
  return row?.value ?? null;
}

export async function setSetting(
  key: AppSettingKey,
  value: string,
): Promise<void> {
  await getDatabase().runAsync(
    `INSERT INTO app_settings (key, value) VALUES (?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value;`,
    [key, value],
  );
}
