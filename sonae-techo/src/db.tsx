import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Db, StockItem, daysUntil } from './types';

const KEY = 'sonae_techo_v1';

const emptyDb = (): Db => ({ items: [], householdSize: 2, targetDays: 7 });

function normalize(raw: any): Db {
  const d: Db = { ...emptyDb(), ...(raw ?? {}) };
  d.items = Array.isArray(d.items) ? d.items : [];
  d.householdSize = Number(d.householdSize) > 0 ? Number(d.householdSize) : 2;
  d.targetDays = Number(d.targetDays) > 0 ? Number(d.targetDays) : 7;
  return d;
}

interface DbContextValue {
  db: Db;
  loaded: boolean;
  update: (fn: (draft: Db) => void) => void;
  replace: (next: Db) => void;
}

const DbContext = createContext<DbContextValue>({
  db: emptyDb(),
  loaded: false,
  update: () => {},
  replace: () => {},
});

export function DbProvider({ children }: { children: React.ReactNode }) {
  const [db, setDb] = useState<Db>(emptyDb());
  const [loaded, setLoaded] = useState(false);
  const dbRef = useRef(db);
  dbRef.current = db;

  useEffect(() => {
    (async () => {
      try {
        const raw = await AsyncStorage.getItem(KEY);
        if (raw) setDb(normalize(JSON.parse(raw)));
      } catch {
        // 壊れたデータは初期化
      }
      setLoaded(true);
    })();
  }, []);

  const persist = (next: Db) => {
    setDb(next);
    AsyncStorage.setItem(KEY, JSON.stringify(next)).catch(() => {});
  };

  const update = (fn: (draft: Db) => void) => {
    const draft: Db = JSON.parse(JSON.stringify(dbRef.current));
    fn(draft);
    persist(draft);
  };

  const replace = (next: Db) => persist(normalize(next));

  return (
    <DbContext.Provider value={{ db, loaded, update, replace }}>
      {children}
    </DbContext.Provider>
  );
}

export const useDb = () => useContext(DbContext);

// ---- 派生ヘルパー ----

export const isPremium = (db: Db) => !!db.premium;
export const isAdFree = (db: Db) => isPremium(db);

/** 期限が近い順に並べたアイテム（期限未設定は含まない） */
export const sortedByExpiry = (items: StockItem[]): StockItem[] =>
  items
    .filter(i => !!i.expiryDate)
    .slice()
    .sort((a, b) => daysUntil(a.expiryDate!) - daysUntil(b.expiryDate!));

/** withinDays 日以内（期限切れ含む）に迫っているアイテム */
export const expiringItems = (items: StockItem[], withinDays = 30): StockItem[] =>
  sortedByExpiry(items).filter(i => daysUntil(i.expiryDate!) <= withinDays);
