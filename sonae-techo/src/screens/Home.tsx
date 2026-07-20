import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useDb, isPremium, expiringItems } from '../db';
import { CATEGORIES, categoryOf, recommendedAmount, unlockedCategories } from '../categories';
import { StockItem, daysUntil, daysUntilLabel, fmtDate } from '../types';
import { colors } from '../config';
import { Card, SectionTitle, st } from '../ui';
import { ItemFormSheet } from './ItemForm';
import { PaywallSheet } from './Settings';

export function HomeScreen() {
  const { db } = useDb();
  const premium = isPremium(db);
  const [editing, setEditing] = useState<StockItem | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [paywallOpen, setPaywallOpen] = useState(false);

  const totals = useMemo(() => {
    const m = new Map<string, number>();
    for (const item of db.items) m.set(item.category, (m.get(item.category) ?? 0) + item.quantity);
    return m;
  }, [db.items]);

  const soon = expiringItems(db.items, 30);
  const unlocked = unlockedCategories(premium);
  const lockedCount = CATEGORIES.length - unlocked.length;

  const openItem = (item: StockItem) => { setEditing(item); setFormOpen(true); };

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 60 }}>
        <SectionTitle>備蓄の状況（{db.householdSize}人・{db.targetDays}日分の目安）</SectionTitle>
        {unlocked.map(cat => {
          const current = totals.get(cat.id) ?? 0;
          const target = recommendedAmount(cat, db.householdSize, db.targetDays);
          const ratio = target > 0 ? Math.min(1, current / target) : current > 0 ? 1 : 0;
          const ok = target === 0 || current >= target;
          return (
            <Card key={cat.id}>
              <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 6 }}>
                <Text style={{ fontSize: 18 }}>{cat.icon} </Text>
                <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>{cat.label}</Text>
                <View style={{ flex: 1 }} />
                <Text style={{ fontSize: 13.5, color: ok ? colors.green : colors.accentDark, fontWeight: '700' }}>
                  {current}{cat.unit}{target > 0 ? ` / 目安${target}${cat.unit}` : ''}
                </Text>
              </View>
              {target > 0 && (
                <View style={{ height: 8, borderRadius: 4, backgroundColor: colors.graySoft, overflow: 'hidden' }}>
                  <View style={{
                    height: '100%', width: `${Math.round(ratio * 100)}%`,
                    backgroundColor: ok ? colors.green : colors.accent,
                  }} />
                </View>
              )}
            </Card>
          );
        })}

        {lockedCount > 0 && (
          <Pressable onPress={() => setPaywallOpen(true)}>
            <Card style={{ alignItems: 'center', backgroundColor: colors.accentSoft, borderColor: colors.accent }}>
              <Text style={{ color: colors.accentDark, fontWeight: '700' }}>
                🔒 プレミアムで残り{lockedCount}カテゴリを解放 ›
              </Text>
            </Card>
          </Pressable>
        )}

        <SectionTitle>期限が近いもの</SectionTitle>
        {soon.length === 0 ? (
          <Card>
            <Text style={st.subText}>30日以内に期限が来るものはありません。</Text>
          </Card>
        ) : soon.map(item => {
          const d = daysUntil(item.expiryDate!);
          const warn = d <= 7;
          return (
            <Pressable key={item.id} onPress={() => openItem(item)}>
              <Card>
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <Text style={{ fontSize: 16 }}>{categoryOf(item.category).icon} </Text>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>{item.name}</Text>
                    <Text style={st.subText}>{item.quantity}{item.unit} ・ 期限 {fmtDate(item.expiryDate)}</Text>
                  </View>
                  <Text style={{ fontSize: 13.5, fontWeight: '700', color: warn ? colors.danger : colors.gold }}>
                    {daysUntilLabel(item.expiryDate!)}
                  </Text>
                </View>
              </Card>
            </Pressable>
          );
        })}

        {db.items.length === 0 && (
          <Text style={[st.subText, { textAlign: 'center', marginTop: 24 }]}>
            まだ何も登録されていません。「一覧」タブの＋ボタンから、水や食料など家にある備蓄品を登録してみましょう。
          </Text>
        )}
      </ScrollView>
      <ItemFormSheet visible={formOpen} item={editing} onClose={() => setFormOpen(false)}
                     onNeedPremium={() => { setFormOpen(false); setPaywallOpen(true); }} />
      <PaywallSheet visible={paywallOpen} onClose={() => setPaywallOpen(false)} />
    </View>
  );
}
