import { getDatabase } from "./database";
import { newId } from "./id";
import type { MaintenanceHistory, NewMaintenanceHistory } from "@/domain/types";

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
