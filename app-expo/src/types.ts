// Web版 date-memo/index.html の localStorage 形式と完全互換のデータ型。
// バックアップJSONを双方向にそのまま読み書きできる。

export type StatusId = 'active' | 'watch' | 'serious' | 'end';

export interface DateRec {
  id: string;
  date: string;        // "yyyy-MM-dd"
  place: string;
  topics: string;
  good: string;
  bad: string;
  next: string;
  nextDate?: string;   // "yyyy-MM-dd"
  rating: number;      // 0-5
}

export interface Partner {
  id: string;
  name: string;
  age: string;
  job: string;
  metVia: string;
  likes: string;
  ng: string;
  memo: string;
  status: StatusId;
  talked: Record<string, boolean>;
  dates: DateRec[];
  createdAt: number;
  updatedAt: number;
}

export interface MyTopic {
  id: string;
  text: string;
  note: string;
}

export interface Db {
  partners: Partner[];
  myTopics: MyTopic[];
  premium?: boolean;
  adFree?: boolean;
  passcode?: string | null;  // SHA-256("datememo:" + code) の16進
  firstRun?: number;
  lastBackup?: number;
}

export const STATUSES: { id: StatusId; label: string; color: string; soft: string }[] = [
  { id: 'active', label: 'やり取り中', color: '#c74564', soft: '#fdeef2' },
  { id: 'watch', label: '様子見', color: '#4a7fb5', soft: '#eaf1f8' },
  { id: 'serious', label: '真剣交際', color: '#2f8a63', soft: '#e7f5ee' },
  { id: 'end', label: 'ご縁なし', color: '#8a7f85', soft: '#f1edef' },
];

export const statusOf = (id: string) => STATUSES.find(s => s.id === id) ?? STATUSES[0];

export const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);

export const todayISO = (offsetDays = 0) => {
  const t = new Date();
  t.setDate(t.getDate() + offsetDays);
  const m = String(t.getMonth() + 1).padStart(2, '0');
  const d = String(t.getDate()).padStart(2, '0');
  return `${t.getFullYear()}-${m}-${d}`;
};

export const fmtDate = (iso?: string) => {
  if (!iso) return '';
  const [y, m, d] = iso.split('-');
  return `${y}/${Number(m)}/${Number(d)}`;
};

export const daysUntil = (iso: string) => {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const target = new Date(iso + 'T00:00:00');
  const n = Math.round((target.getTime() - now.getTime()) / 86400000);
  return n <= 0 ? '今日！' : `あと${n}日`;
};

export const lastDate = (p: Partner): DateRec | undefined =>
  [...p.dates].sort((a, b) => b.date.localeCompare(a.date))[0];

export const avgRating = (p: Partner): number => {
  const rated = p.dates.filter(d => d.rating > 0);
  if (!rated.length) return 0;
  return Math.round(rated.reduce((s, d) => s + d.rating, 0) / rated.length);
};

export const nextUpcoming = (p: Partner): string | null => {
  const today = todayISO();
  const ds = p.dates
    .map(d => d.nextDate)
    .filter((d): d is string => !!d && d >= today)
    .sort();
  return ds[0] ?? null;
};

export const samplePartner = (): Partner => ({
  id: uid(),
  name: 'サンプル：Aさん',
  age: '31',
  job: 'メーカー営業',
  metVia: '婚活アプリ',
  likes: 'カフェ巡り、猫、温泉',
  ng: '仕事の愚痴は控えめに',
  memo: '笑顔が素敵。会話のテンポが合う',
  status: 'active',
  talked: { a1: true, a2: true },
  createdAt: Date.now(),
  updatedAt: Date.now(),
  dates: [{
    id: uid(),
    date: todayISO(-7),
    place: '駅前のカフェでお茶',
    rating: 4,
    topics: '休日の過ごし方、出身地の話',
    good: '聞き上手で話しやすかった',
    bad: '少し緊張していたかも',
    next: '水族館デート。誕生日を聞く',
    nextDate: todayISO(7),
  }],
});
