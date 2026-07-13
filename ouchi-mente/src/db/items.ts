import { getDatabase } from "./database";
import { newId } from "./id";
import type {
  MaintenanceCategory,
  MaintenanceItem,
  MaintenanceTaskType,
  NewMaintenanceItem,
  ScheduleType,
  IntervalUnit,
} from "@/domain/types";

type ItemRow = {
  id: string;
  name: string;
  category: string;
  task_type: string;
  location: string | null;
  manufacturer: string | null;
  model_number: string | null;
  note: string | null;
  image_uri: string | null;
  schedule_type: string;
  interval_value: number | null;
  interval_unit: string | null;
  next_due_date: string | null;
  notification_enabled: number;
  notification_timing_days: number | null;
  notification_id: string | null;
  created_at: string;
  updated_at: string;
  archived_at: string | null;
};

function rowToItem(row: ItemRow): MaintenanceItem {
  return {
    id: row.id,
    name: row.name,
    category: row.category as MaintenanceCategory,
    taskType: row.task_type as MaintenanceTaskType,
    location: row.location ?? undefined,
    manufacturer: row.manufacturer ?? undefined,
    modelNumber: row.model_number ?? undefined,
    note: row.note ?? undefined,
    imageUri: row.image_uri ?? undefined,
    scheduleType: row.schedule_type as ScheduleType,
    intervalValue: row.interval_value ?? undefined,
    intervalUnit: (row.interval_unit as IntervalUnit | null) ?? undefined,
    nextDueDate: row.next_due_date ?? undefined,
    notificationEnabled: row.notification_enabled === 1,
    notificationTimingDays: row.notification_timing_days ?? undefined,
    notificationId: row.notification_id ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    archivedAt: row.archived_at ?? undefined,
  };
}

export async function listItems(): Promise<MaintenanceItem[]> {
  const rows = await getDatabase().getAllAsync<ItemRow>(
    `SELECT * FROM maintenance_items
     WHERE archived_at IS NULL
     ORDER BY next_due_date IS NULL, next_due_date ASC, name ASC;`,
  );
  return rows.map(rowToItem);
}

export async function getItem(id: string): Promise<MaintenanceItem | null> {
  const row = await getDatabase().getFirstAsync<ItemRow>(
    "SELECT * FROM maintenance_items WHERE id = ?;",
    [id],
  );
  return row ? rowToItem(row) : null;
}

export async function countItems(): Promise<number> {
  const row = await getDatabase().getFirstAsync<{ count: number }>(
    "SELECT COUNT(*) AS count FROM maintenance_items WHERE archived_at IS NULL;",
  );
  return row?.count ?? 0;
}

export async function insertItem(
  input: NewMaintenanceItem,
): Promise<MaintenanceItem> {
  const now = new Date().toISOString();
  const item: MaintenanceItem = {
    ...input,
    id: newId(),
    createdAt: now,
    updatedAt: now,
  };
  await getDatabase().runAsync(
    `INSERT INTO maintenance_items (
      id, name, category, task_type, location, manufacturer, model_number,
      note, image_uri, schedule_type, interval_value, interval_unit,
      next_due_date, notification_enabled, notification_timing_days,
      notification_id, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);`,
    [
      item.id,
      item.name,
      item.category,
      item.taskType,
      item.location ?? null,
      item.manufacturer ?? null,
      item.modelNumber ?? null,
      item.note ?? null,
      item.imageUri ?? null,
      item.scheduleType,
      item.intervalValue ?? null,
      item.intervalUnit ?? null,
      item.nextDueDate ?? null,
      item.notificationEnabled ? 1 : 0,
      item.notificationTimingDays ?? null,
      item.notificationId ?? null,
      item.createdAt,
      item.updatedAt,
      item.archivedAt ?? null,
    ],
  );
  return item;
}

export async function updateItem(item: MaintenanceItem): Promise<MaintenanceItem> {
  const updated: MaintenanceItem = {
    ...item,
    updatedAt: new Date().toISOString(),
  };
  await getDatabase().runAsync(
    `UPDATE maintenance_items SET
      name = ?, category = ?, task_type = ?, location = ?, manufacturer = ?,
      model_number = ?, note = ?, image_uri = ?, schedule_type = ?,
      interval_value = ?, interval_unit = ?, next_due_date = ?,
      notification_enabled = ?, notification_timing_days = ?,
      notification_id = ?, updated_at = ?, archived_at = ?
    WHERE id = ?;`,
    [
      updated.name,
      updated.category,
      updated.taskType,
      updated.location ?? null,
      updated.manufacturer ?? null,
      updated.modelNumber ?? null,
      updated.note ?? null,
      updated.imageUri ?? null,
      updated.scheduleType,
      updated.intervalValue ?? null,
      updated.intervalUnit ?? null,
      updated.nextDueDate ?? null,
      updated.notificationEnabled ? 1 : 0,
      updated.notificationTimingDays ?? null,
      updated.notificationId ?? null,
      updated.updatedAt,
      updated.archivedAt ?? null,
      updated.id,
    ],
  );
  return updated;
}

/** 項目削除。履歴は ON DELETE CASCADE でまとめて削除される */
export async function deleteItem(id: string): Promise<void> {
  await getDatabase().runAsync("DELETE FROM maintenance_items WHERE id = ?;", [
    id,
  ]);
}
