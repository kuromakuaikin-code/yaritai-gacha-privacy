import React, { useState } from 'react';
import { Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { RouteProp, useNavigation, useRoute } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDb, allTopicCount, talkedCount, untalkedItems } from '../db';
import { colors } from '../config';
import { DateRec, Partner, daysUntil, fmtDate, todayISO, uid } from '../types';
import { Avatar, Card, Field, PrimaryButton, Sheet, StatusBadge, Stars, SubButton, st } from '../ui';
import { PartnerFormSheet, RootStackParams } from './Partners';
import { GachaSheet } from './Topics';

type Nav = NativeStackNavigationProp<RootStackParams>;

export function PartnerDetailScreen() {
  const { db } = useDb();
  const nav = useNavigation<Nav>();
  const route = useRoute<RouteProp<RootStackParams, 'PartnerDetail'>>();
  const partner = db.partners.find(p => p.id === route.params.partnerId);

  const [editOpen, setEditOpen] = useState(false);
  const [recordOpen, setRecordOpen] = useState(false);
  const [editingRec, setEditingRec] = useState<DateRec | null>(null);

  if (!partner) {
    return <View style={st.screen} />;
  }
  const sorted = [...partner.dates].sort((a, b) => b.date.localeCompare(a.date));
  const meta = [partner.age && `${partner.age}歳`, partner.job, partner.metVia]
    .filter(Boolean).join('・');

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 60 }}>
        <Card>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            <Avatar name={partner.name} />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 17, fontWeight: '700', color: colors.text }}>
                {partner.name}
              </Text>
              <Text style={st.subText}>{meta || ' '}</Text>
            </View>
            <StatusBadge status={partner.status} />
          </View>
          {partner.likes ? <Info label="好きなもの" text={partner.likes} /> : null}
          {partner.ng ? <Info label="NG・地雷" text={partner.ng} color={colors.danger} /> : null}
          {partner.memo ? <Info label="メモ" text={partner.memo} /> : null}
          <Pressable onPress={() => setEditOpen(true)} style={{ alignSelf: 'flex-end', marginTop: 8 }}>
            <Text style={{ color: colors.accentDark, fontWeight: '700' }}>プロフィールを編集</Text>
          </Pressable>
        </Card>

        <Pressable onPress={() => nav.navigate('Brief', { partnerId: partner.id })}>
          <Card style={{ flexDirection: 'row', alignItems: 'center' }}>
            <Text style={st.rowText}>📋 デート前カンペ</Text>
            <View style={{ flex: 1 }} />
            <Text style={st.subText}>直前チェック用 ›</Text>
          </Card>
        </Pressable>
        <Pressable onPress={() => nav.navigate('Checklist', { partnerId: partner.id })}>
          <Card style={{ flexDirection: 'row', alignItems: 'center' }}>
            <Text style={st.rowText}>💬 話題チェック</Text>
            <View style={{ flex: 1 }} />
            <Text style={st.subText}>
              {talkedCount(db, partner)} / {allTopicCount(db)} 話した ›
            </Text>
          </Card>
        </Pressable>

        <View style={st.secTitle}>
          <Text style={st.secTitleText}>デート記録（{partner.dates.length}回）</Text>
          <View style={{ flex: 1 }} />
          <Pressable onPress={() => { setEditingRec(null); setRecordOpen(true); }}>
            <Text style={{ color: colors.accentDark, fontWeight: '700' }}>＋ 記録を追加</Text>
          </Pressable>
        </View>

        {sorted.length === 0 && (
          <Text style={[st.subText, { textAlign: 'center', padding: 20 }]}>
            まだ記録がありません。デートの後に振り返りを残しましょう。
          </Text>
        )}
        {sorted.map((rec, i) => (
          <Card key={rec.id}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <View style={{
                backgroundColor: colors.accentSoft, borderRadius: 999,
                paddingHorizontal: 9, paddingVertical: 2,
              }}>
                <Text style={{ color: colors.accentDark, fontSize: 12, fontWeight: '700' }}>
                  {sorted.length - i}回目
                </Text>
              </View>
              <Text style={{ fontWeight: '700', color: colors.text }}>{fmtDate(rec.date)}</Text>
              <Text style={[st.subText, { flex: 1 }]} numberOfLines={1}>{rec.place}</Text>
              <Pressable onPress={() => { setEditingRec(rec); setRecordOpen(true); }} hitSlop={8}>
                <Text style={st.subText}>編集</Text>
              </Pressable>
            </View>
            {rec.rating > 0 && <View style={{ marginTop: 4 }}><Stars n={rec.rating} /></View>}
            {rec.topics ? <Text style={[st.rowText, { marginTop: 4 }]}>{rec.topics}</Text> : null}
            {rec.good ? <Info label="👍 良かったこと" text={rec.good} color={colors.green} /> : null}
            {rec.bad ? <Info label="🤔 気になったこと" text={rec.bad} color={colors.danger} /> : null}
            {(rec.next || rec.nextDate) ? (
              <Info
                label={`📌 次回・宿題${rec.nextDate ? `（${fmtDate(rec.nextDate)}）` : ''}`}
                text={rec.next} color={colors.blue} />
            ) : null}
          </Card>
        ))}
      </ScrollView>

      <PartnerFormSheet visible={editOpen} partner={partner} onClose={() => setEditOpen(false)} />
      <DateFormSheet visible={recordOpen} partner={partner} record={editingRec}
                     onClose={() => setRecordOpen(false)} />
    </View>
  );
}

function Info({ label, text, color }: { label: string; text: string; color?: string }) {
  return (
    <View style={{ marginTop: 8 }}>
      <Text style={{ fontSize: 12.5, fontWeight: '700', color: color ?? colors.sub }}>{label}</Text>
      {text ? <Text style={[st.rowText, { marginTop: 1 }]}>{text}</Text> : null}
    </View>
  );
}

function DateFormSheet({ visible, partner, record, onClose }: {
  visible: boolean; partner: Partner; record: DateRec | null; onClose: () => void;
}) {
  const { update } = useDb();
  const [date, setDate] = useState(todayISO());
  const [place, setPlace] = useState('');
  const [topics, setTopics] = useState('');
  const [good, setGood] = useState('');
  const [bad, setBad] = useState('');
  const [next, setNext] = useState('');
  const [nextDate, setNextDate] = useState('');
  const [rating, setRating] = useState(0);

  React.useEffect(() => {
    if (!visible) return;
    setDate(record?.date ?? todayISO());
    setPlace(record?.place ?? '');
    setTopics(record?.topics ?? '');
    setGood(record?.good ?? '');
    setBad(record?.bad ?? '');
    setNext(record?.next ?? '');
    setNextDate(record?.nextDate ?? '');
    setRating(record?.rating ?? 0);
  }, [visible, record]);

  const validDate = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s);

  const save = () => {
    if (!validDate(date)) { Alert.alert('日付は YYYY-MM-DD 形式で入力してください'); return; }
    if (nextDate && !validDate(nextDate)) {
      Alert.alert('次回の予定日は YYYY-MM-DD 形式で入力してください'); return;
    }
    update(d => {
      const p = d.partners.find(x => x.id === partner.id);
      if (!p) return;
      const vals = { date, place, topics, good, bad, next, nextDate: nextDate || undefined, rating };
      if (record) {
        const r = p.dates.find(x => x.id === record.id);
        if (r) Object.assign(r, vals);
      } else {
        p.dates.push({ id: uid(), ...vals });
      }
      p.updatedAt = Date.now();
    });
    onClose();
  };

  const remove = () => {
    if (!record) return;
    Alert.alert('この記録を削除します。よろしいですか？', '', [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除する', style: 'destructive',
        onPress: () => {
          update(d => {
            const p = d.partners.find(x => x.id === partner.id);
            if (!p) return;
            p.dates = p.dates.filter(x => x.id !== record.id);
            p.updatedAt = Date.now();
          });
          onClose();
        },
      },
    ]);
  };

  return (
    <Sheet visible={visible} onClose={onClose}
           title={record ? 'デート記録を編集' : 'デート記録を追加'}>
      <Field label="日付（YYYY-MM-DD）*" value={date} onChange={setDate} placeholder={todayISO()} />
      <Field label="場所・プラン" value={place} onChange={setPlace}
             placeholder="例：表参道でランチ→散歩" />
      <Text style={st.fieldLabel}>手応え</Text>
      <View style={{ flexDirection: 'row', gap: 6, marginBottom: 12 }}>
        {[1, 2, 3, 4, 5].map(n => (
          <Pressable key={n} onPress={() => setRating(rating === n ? 0 : n)} hitSlop={6}>
            <Text style={{ fontSize: 30, color: n <= rating ? colors.gold : '#c9bfc4' }}>★</Text>
          </Pressable>
        ))}
      </View>
      <Field label="話したこと・内容" value={topics} onChange={setTopics} multiline
             placeholder="例：お互いの休日の過ごし方、家族の話" />
      <Field label="👍 良かったこと" value={good} onChange={setGood} multiline
             placeholder="例：店員さんへの態度が丁寧だった" />
      <Field label="🤔 気になったこと" value={bad} onChange={setBad} multiline
             placeholder="例：会話中スマホをよく見ていた" />
      <Field label="📌 次回の予定・宿題" value={next} onChange={setNext} multiline
             placeholder="例：次はおすすめの水族館へ。誕生日を聞く" />
      <Field label="📅 次回の予定日（YYYY-MM-DD・任意）" value={nextDate} onChange={setNextDate}
             placeholder={todayISO(7)} />
      <PrimaryButton label="保存" onPress={save} />
      {record && (
        <Pressable onPress={remove} style={{ alignItems: 'center', padding: 14 }}>
          <Text style={{ color: colors.danger }}>この記録を削除</Text>
        </Pressable>
      )}
      <View style={{ height: 24 }} />
    </Sheet>
  );
}

export function BriefScreen() {
  const { db } = useDb();
  const route = useRoute<RouteProp<RootStackParams, 'Brief'>>();
  const partner = db.partners.find(p => p.id === route.params.partnerId);
  const [gachaOpen, setGachaOpen] = useState(false);

  if (!partner) return <View style={st.screen} />;
  const ld = [...partner.dates].sort((a, b) => b.date.localeCompare(a.date))[0];
  const nd = (() => {
    const today = todayISO();
    return partner.dates.map(d => d.nextDate)
      .filter((x): x is string => !!x && x >= today).sort()[0] ?? null;
  })();
  const untalked = untalkedItems(db, partner).slice(0, 5);

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 60 }}>
        {(nd || ld?.next) ? (
          <Card style={{ borderColor: colors.blue }}>
            <Text style={{ color: colors.blue, fontWeight: '700', fontSize: 13 }}>📌 次の予定</Text>
            <Text style={[st.rowText, { marginTop: 3 }]}>
              {nd ? `${fmtDate(nd)}（${daysUntil(nd)}） ` : ''}{ld?.next ?? ''}
            </Text>
          </Card>
        ) : null}
        {partner.ng ? (
          <Card style={{ borderColor: colors.danger }}>
            <Text style={{ color: colors.danger, fontWeight: '700', fontSize: 13 }}>
              ⚠️ NG・地雷（触れない）
            </Text>
            <Text style={[st.rowText, { marginTop: 3 }]}>{partner.ng}</Text>
          </Card>
        ) : null}
        {partner.likes ? (
          <Card>
            <Text style={{ color: colors.green, fontWeight: '700', fontSize: 13 }}>
              💚 好きなもの・趣味
            </Text>
            <Text style={[st.rowText, { marginTop: 3 }]}>{partner.likes}</Text>
          </Card>
        ) : null}
        {ld ? (
          <Card>
            <Text style={[st.subText, { fontWeight: '700' }]}>
              🕐 前回のデート（{fmtDate(ld.date)}{ld.place ? '・' + ld.place : ''}）
            </Text>
            {ld.good ? <Text style={[st.rowText, { marginTop: 4 }]}>👍 {ld.good}</Text> : null}
            {ld.bad ? <Text style={[st.rowText, { marginTop: 4 }]}>🤔 {ld.bad}</Text> : null}
          </Card>
        ) : null}
        <View style={st.secTitle}>
          <Text style={st.secTitleText}>💬 まだ話していない話題</Text>
        </View>
        {untalked.length === 0 ? (
          <Card><Text style={st.rowText}>解放中の話題は全て話しました 🎉</Text></Card>
        ) : (
          <Card>
            {untalked.map(t => (
              <Text key={t.id} style={[st.rowText, { paddingVertical: 5 }]}>
                {t.isMy ? '📝 ' : ''}{t.isMy ? t.q : t.title}
              </Text>
            ))}
          </Card>
        )}
        <SubButton label="🎲 話題ガチャで3つ引く" onPress={() => setGachaOpen(true)} />
      </ScrollView>
      <GachaSheet visible={gachaOpen} partnerId={partner.id} onClose={() => setGachaOpen(false)} />
    </View>
  );
}
