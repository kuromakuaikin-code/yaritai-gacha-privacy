import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Crypto from 'expo-crypto';
import { Db, MyTopic, Partner } from './types';
import { unlockedTopics } from './topics';

const KEY = 'konkatsu_date_memo_v1';

const emptyDb = (): Db => ({ partners: [], myTopics: [], passcode: null });

function normalize(raw: any): Db {
  const d: Db = { ...emptyDb(), ...(raw ?? {}) };
  d.partners = Array.isArray(d.partners) ? d.partners : [];
  d.myTopics = Array.isArray(d.myTopics) ? d.myTopics : [];
  // Web旧版のカテゴリ別カスタム話題を MY話題 に統合
  const legacy = Array.isArray((raw ?? {}).custom) ? (raw as any).custom : [];
  for (const c of legacy) {
    if (c && c.id && c.text) d.myTopics.push({ id: c.id, text: c.text, note: '' });
  }
  for (const p of d.partners) {
    p.talked = p.talked ?? {};
    p.dates = Array.isArray(p.dates) ? p.dates : [];
  }
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

export const allTopicCount = (db: Db) =>
  unlockedTopics(isPremium(db)).length + db.myTopics.length;

export const talkedCount = (db: Db, p: Partner) => {
  const valid = new Set<string>([
    ...unlockedTopics(isPremium(db)).map(t => t.id),
    ...db.myTopics.map(t => t.id),
  ]);
  return Object.keys(p.talked).filter(id => p.talked[id] && valid.has(id)).length;
};

export interface UntalkedItem {
  id: string;
  title: string;
  q: string;
  hint?: [string, string];
  note?: string;
  isMy: boolean;
}

export const untalkedItems = (db: Db, p: Partner | null): UntalkedItem[] => {
  const talked = p?.talked ?? {};
  const items: UntalkedItem[] = unlockedTopics(isPremium(db))
    .filter(t => !talked[t.id])
    .map(t => ({
      id: t.id,
      title: t.title,
      q: t.flow.q,
      hint: t.flow.d[Math.floor(Math.random() * t.flow.d.length)],
      isMy: false,
    }));
  for (const m of db.myTopics) {
    if (!talked[m.id]) {
      items.push({ id: m.id, title: 'MY話題', q: m.text, note: m.note, isMy: true });
    }
  }
  return items;
};

export const hashPasscode = async (code: string) =>
  Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, 'datememo:' + code);
