import { getDatabase } from "./database";
import { newId } from "./id";
import type {
  MaintenanceHistory,
  MaintenanceItem,
  NewMaintenanceHistory,
} from "@/domain/types";

type HistoryRow = {
  id: string;
  maintenance_item_id: string;
  completed_at: string;
  note: string | null;
  image_uri: string | null;
  calculated_next_due_date: string | null;
  created_at: string;
  updated_at: string;
};

function rowToHistory(row: HistoryRow): MaintenanceHistory {
  return {
    id: row.id,
    maintenanceItemId: row.maintenance_item_id,
    completedAt: row.completed_at,
    note: row.note ?? undefined,
    imageUri: row.image_uri ?? undefined,
    calculatedNextDueDate: row.calculated_next_due_date ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listHistoryForItem(
  maintenanceItemId: string,
): Promise<MaintenanceHistory[]> {
  const rows = await getDatabase().getAllAsync<HistoryRow>(
    `SELECT * FROM maintenance_history
     WHERE maintenance_item_id = ?
     ORDER BY completed_at DESC, created_at DESC;`,
    [maintenanceItemId],
  );
  return rows.map(rowToHistory);
}

export async function getHistory(id: string): Promise<MaintenanceHistory | null> {
  const row = await getDatabase().getFirstAsync<HistoryRow>(
    "SELECT * FROM maintenance_history WHERE id = ?;",
    [id],
  );
  return row ? rowToHistory(row) : null;
}

export async function getLatestHistoryForItem(
  maintenanceItemId: string,
): Promise<MaintenanceHistory | null> {
  const row = await getDatabase().getFirstAsync<HistoryRow>(
    `SELECT * FROM maintenance_history
     WHERE maintenance_item_id = ?
     ORDER BY completed_at DESC, created_at DESC
     LIMIT 1;`,
    [maintenanceItemId],
  );
  return row ? rowToHistory(row) : null;
}

export async function insertHistory(
  input: NewMaintenanceHistory,
): Promise<MaintenanceHistory> {
  const now = new Date().toISOString();
  const history: MaintenanceHistory = {
    ...input,
    id: newId(),
    createdAt: now,
    updatedAt: now,
  };
  await getDatabase().runAsync(
    `INSERT INTO maintenance_history (
      id, maintenance_item_id, completed_at, note, image_uri,
      calculated_next_due_date, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);`,
    [
      history.id,
      history.maintenanceItemId,
      history.completedAt,
      history.note ?? null,
      history.imageUri ?? null,
      history.calculatedNextDueDate ?? null,
      history.createdAt,
      history.updatedAt,
    ],
  );
  return history;
}

export async function updateHistory(
  history: MaintenanceHistory,
): Promise<MaintenanceHistory> {
  const updated: MaintenanceHistory = {
    ...history,
    updatedAt: new Date().toISOString(),
  };
  await getDatabase().runAsync(
    `UPDATE maintenance_history SET
      completed_at = ?, note = ?, image_uri = ?,
      calculated_next_due_date = ?, updated_at = ?
    WHERE id = ?;`,
    [
      updated.completedAt,
      updated.note ?? null,
      updated.imageUri ?? null,
      updated.calculatedNextDueDate ?? null,
      updated.updatedAt,
      updated.id,
    ],
  );
  return updated;
}

export async function deleteHistory(id: string): Promise<void> {
  await getDatabase().runAsync(
    "DELETE FROM maintenance_history WHERE id = ?;",
    [id],
  );
}

/** 履歴修正と、それに伴う項目の予定日修正を同時に確定する。 */
export async function updateHistoryAndItem(
  history: MaintenanceHistory,
  item?: MaintenanceItem,
): Promise<{ history: MaintenanceHistory; item?: MaintenanceItem }> {
  const updatedHistory: MaintenanceHistory = {
    ...history,
    updatedAt: new Date().toISOString(),
  };
  const updatedItem = item
    ? { ...item, updatedAt: new Date().toISOString() }
    : undefined;

  await getDatabase().withExclusiveTransactionAsync(async (txn) => {
    await txn.runAsync(
      `UPDATE maintenance_history SET
        completed_at = ?, note = ?, image_uri = ?,
        calculated_next_due_date = ?, updated_at = ?
      WHERE id = ?;`,
      [
        updatedHistory.completedAt, updatedHistory.note ?? null,
        updatedHistory.imageUri ?? null,
        updatedHistory.calculatedNextDueDate ?? null, updatedHistory.updatedAt,
        updatedHistory.id,
      ],
    );
    if (updatedItem) {
      await txn.runAsync(
        `UPDATE maintenance_items SET
          name = ?, category = ?, task_type = ?, location = ?, manufacturer = ?,
          model_number = ?, note = ?, image_uri = ?, schedule_type = ?,
          interval_value = ?, interval_unit = ?, next_due_date = ?,
          notification_enabled = ?, notification_timing_days = ?,
          notification_id = ?, updated_at = ?, archived_at = ?
        WHERE id = ?;`,
        [
          updatedItem.name, updatedItem.category, updatedItem.taskType,
          updatedItem.location ?? null, updatedItem.manufacturer ?? null,
          updatedItem.modelNumber ?? null, updatedItem.note ?? null,
          updatedItem.imageUri ?? null, updatedItem.scheduleType,
          updatedItem.intervalValue ?? null, updatedItem.intervalUnit ?? null,
          updatedItem.nextDueDate ?? null,
          updatedItem.notificationEnabled ? 1 : 0,
          updatedItem.notificationTimingDays ?? null,
          updatedItem.notificationId ?? null, updatedItem.updatedAt,
          updatedItem.archivedAt ?? null, updatedItem.id,
        ],
      );
    }
  });
  return { history: updatedHistory, item: updatedItem };
}
