import React, { useMemo, useState } from 'react';
import { Alert, FlatList, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDb, isPremium, talkedCount } from '../db';
import { FREE_PARTNER_LIMIT, colors } from '../config';
import {
  Partner, StatusId, STATUSES, avgRating, daysUntil, fmtDate, lastDate,
  nextUpcoming, samplePartner, statusOf, uid,
} from '../types';
import { Avatar, Card, Chip, Field, PrimaryButton, Sheet, StatusBadge, Stars, SubButton, st } from '../ui';
import { PaywallSheet } from './Settings';

export type RootStackParams = {
  PartnerList: undefined;
  PartnerDetail: { partnerId: string };
  Brief: { partnerId: string };
  Checklist: { partnerId: string };
};

type Nav = NativeStackNavigationProp<RootStackParams>;

type SortKey = 'upd' | 'next' | 'last' | 'rate';
const SORTS: { key: SortKey; label: string }[] = [
  { key: 'upd', label: '更新順' },
  { key: 'next', label: '予定が近い順' },
  { key: 'last', label: 'デート日順' },
  { key: 'rate', label: '評価順' },
];

export function PartnersScreen() {
  const { db, update } = useDb();
  const nav = useNavigation<Nav>();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<StatusId | 'all'>('all');
  const [sort, setSort] = useState<SortKey>('upd');
  const [formOpen, setFormOpen] = useState(false);
  const [paywallOpen, setPaywallOpen] = useState(false);

  const list = useMemo(() => {
    let l = db.partners.filter(p => filter === 'all' || p.status === filter);
    if (query) {
      const q = query.toLowerCase();
      l = l.filter(p => (p.name + p.job + p.metVia + p.memo).toLowerCase().includes(q));
    }
    return [...l].sort((a, b) => {
      if (sort === 'rate') return avgRating(b) - avgRating(a);
      if (sort === 'last') {
        return (lastDate(b)?.date ?? '').localeCompare(lastDate(a)?.date ?? '');
      }
      if (sort === 'next') {
        return (nextUpcoming(a) ?? '9999').localeCompare(nextUpcoming(b) ?? '9999');
      }
      return (b.updatedAt ?? 0) - (a.updatedAt ?? 0);
    });
  }, [db.partners, query, filter, sort]);

  const onAdd = () => {
    if (!isPremium(db) && db.partners.length >= FREE_PARTNER_LIMIT) {
      setPaywallOpen(true);
    } else {
      setFormOpen(true);
    }
  };

  return (
    <View style={st.screen}>
      <FlatList
        data={list}
        keyExtractor={p => p.id}
        contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
        ListHeaderComponent={
          <View>
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 10 }}>
              <TextInput
                style={[st.input, { flex: 1 }]}
                value={query}
                onChangeText={setQuery}
                placeholder="名前・職業・出会いで検索"
                placeholderTextColor="#b9a9b0"
              />
            </View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 6 }}>
              <Chip label="すべて" on={filter === 'all'} onPress={() => setFilter('all')} />
              {STATUSES.map(s => (
                <Chip key={s.id} label={s.label} color={s.color}
                      on={filter === s.id} onPress={() => setFilter(s.id)} />
              ))}
            </ScrollView>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 10 }}>
              {SORTS.map(s => (
                <Chip key={s.key} label={s.label} on={sort === s.key}
                      onPress={() => setSort(s.key)} />
              ))}
            </ScrollView>
          </View>
        }
        ListEmptyComponent={
          db.partners.length === 0 ? (
            <View style={{ alignItems: 'center', paddingVertical: 48 }}>
              <Text style={{ fontSize: 44 }}>💐</Text>
              <Text style={[st.subText, { textAlign: 'center', marginTop: 8 }]}>
                お相手がまだ登録されていません。{'\n'}右下の「＋」から追加しましょう。
              </Text>
              <View style={{ width: 240, marginTop: 12 }}>
                <SubButton label="サンプルデータを入れてみる"
                           onPress={() => update(d => { d.partners.push(samplePartner()); })} />
              </View>
            </View>
          ) : (
            <View style={{ alignItems: 'center', paddingVertical: 48 }}>
              <Text style={{ fontSize: 40 }}>🔍</Text>
              <Text style={[st.subText, { marginTop: 8 }]}>条件に合うお相手が見つかりません</Text>
            </View>
          )
        }
        renderItem={({ item }) => (
          <PartnerCard partner={item}
                       onPress={() => nav.navigate('PartnerDetail', { partnerId: item.id })} />
        )}
      />

      <Pressable onPress={onAdd} style={{
        position: 'absolute', right: 20, bottom: 24,
        width: 58, height: 58, borderRadius: 29,
        backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center',
        shadowColor: colors.accentDark, shadowOpacity: 0.4, shadowRadius: 8,
        shadowOffset: { width: 0, height: 4 }, elevation: 5,
      }}>
        <Text style={{ color: '#fff', fontSize: 30, marginTop: -2 }}>＋</Text>
      </Pressable>

      <PartnerFormSheet visible={formOpen} partner={null} onClose={() => setFormOpen(false)} />
      <PaywallSheet visible={paywallOpen} onClose={() => setPaywallOpen(false)}
                    message={`無料版で登録できるお相手は${FREE_PARTNER_LIMIT}人までです。プレミアムで無制限になります。`} />
    </View>
  );
}

function PartnerCard({ partner: p, onPress }: { partner: Partner; onPress: () => void }) {
  const ld = lastDate(p);
  const nd = nextUpcoming(p);
  const av = avgRating(p);
  const meta = [p.age && `${p.age}歳`, p.job, p.metVia].filter(Boolean).join('・');
  return (
    <Pressable onPress={onPress}>
      <Card>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <Avatar name={p.name} />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 17, fontWeight: '700', color: colors.text }}>{p.name}</Text>
            <Text style={st.subText}>{meta || ' '}</Text>
          </View>
          <StatusBadge status={p.status} />
        </View>
        <View style={{ flexDirection: 'row', gap: 10, marginTop: 8, alignItems: 'center' }}>
          <Text style={st.subText}>💬 {p.dates.length}回</Text>
          {ld && <Text style={st.subText}>📅 {fmtDate(ld.date)}</Text>}
          <Stars n={av} />
        </View>
        {(nd || ld?.next) ? (
          <Text numberOfLines={1}
                style={{ color: colors.blue, fontSize: 13.5, fontWeight: '600', marginTop: 6 }}>
            📌 次回：{nd ? `${fmtDate(nd)}（${daysUntil(nd)}） ` : ''}{ld?.next ?? ''}
          </Text>
        ) : null}
      </Card>
    </Pressable>
  );
}

export function PartnerFormSheet({ visible, partner, onClose }: {
  visible: boolean; partner: Partner | null; onClose: () => void;
}) {
  const { db, update } = useDb();
  const nav = useNavigation<Nav>();
  const [name, setName] = useState('');
  const [age, setAge] = useState('');
  const [job, setJob] = useState('');
  const [metVia, setMetVia] = useState('');
  const [likes, setLikes] = useState('');
  const [ng, setNg] = useState('');
  const [memo, setMemo] = useState('');
  const [status, setStatus] = useState<StatusId>('active');

  React.useEffect(() => {
    if (!visible) return;
    setName(partner?.name ?? '');
    setAge(partner?.age ?? '');
    setJob(partner?.job ?? '');
    setMetVia(partner?.metVia ?? '');
    setLikes(partner?.likes ?? '');
    setNg(partner?.ng ?? '');
    setMemo(partner?.memo ?? '');
    setStatus(partner?.status ?? 'active');
  }, [visible, partner]);

  const save = () => {
    const n = name.trim();
    if (!n) { Alert.alert('名前を入力してください'); return; }
    update(d => {
      if (partner) {
        const p = d.partners.find(x => x.id === partner.id);
        if (!p) return;
        Object.assign(p, { name: n, age, job, metVia, likes, ng, memo, status, updatedAt: Date.now() });
      } else {
        d.partners.push({
          id: uid(), name: n, age, job, metVia, likes, ng, memo, status,
          talked: {}, dates: [], createdAt: Date.now(), updatedAt: Date.now(),
        });
      }
    });
    onClose();
  };

  const remove = () => {
    if (!partner) return;
    Alert.alert('お相手を削除', `「${partner.name}」を記録ごと削除します。よろしいですか？`, [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除する', style: 'destructive',
        onPress: () => {
          update(d => { d.partners = d.partners.filter(x => x.id !== partner.id); });
          onClose();
          nav.navigate('PartnerList');
        },
      },
    ]);
  };

  return (
    <Sheet visible={visible} onClose={onClose}
           title={partner ? 'プロフィールを編集' : 'お相手を追加'}>
      <Field label="名前・ニックネーム *" value={name} onChange={setName}
             placeholder="例：Aさん、カフェの田中さん" />
      <Field label="年齢" value={age} onChange={setAge} keyboardType="number-pad" placeholder="32" />
      <Text style={st.fieldLabel}>ステータス</Text>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 12, rowGap: 8 }}>
        {STATUSES.map(s => (
          <Chip key={s.id} label={s.label} color={s.color}
                on={status === s.id} onPress={() => setStatus(s.id)} />
        ))}
      </View>
      <Field label="職業" value={job} onChange={setJob} placeholder="例：メーカー営業" />
      <Field label="出会い" value={metVia} onChange={setMetVia}
             placeholder="例：婚活アプリ、相談所、友人の紹介" />
      <Field label="好きなもの・趣味" value={likes} onChange={setLikes} multiline
             placeholder="例：コーヒー、登山、猫を飼っている" />
      <Field label="NG・地雷（触れない話題など）" value={ng} onChange={setNg} multiline
             placeholder="例：転職の話は避ける" />
      <Field label="メモ" value={memo} onChange={setMemo} multiline
             placeholder="第一印象、家族構成など" />
      <PrimaryButton label="保存" onPress={save} />
      {partner && (
        <Pressable onPress={remove} style={{ alignItems: 'center', padding: 14 }}>
          <Text style={{ color: colors.danger }}>このお相手を削除</Text>
        </Pressable>
      )}
      <View style={{ height: 24 }} />
    </Sheet>
  );
}
