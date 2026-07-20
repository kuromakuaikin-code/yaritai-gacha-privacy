import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';
import { useDb, isPremium } from '../db';
import { CATEGORIES, categoryOf, isFreeCategory } from '../categories';
import { CategoryId, StockItem, daysUntil, daysUntilLabel, fmtDate } from '../types';
import { colors } from '../config';
import { Card, Chip, st } from '../ui';
import { ItemFormSheet } from './ItemForm';
import { PaywallSheet } from './Settings';

export function ListScreen() {
  const { db } = useDb();
  const premium = isPremium(db);
  const [filter, setFilter] = useState<CategoryId | 'all'>('all');
  const [editing, setEditing] = useState<StockItem | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [paywallOpen, setPaywallOpen] = useState(false);

  const items = useMemo(() => {
    const filtered = filter === 'all' ? db.items : db.items.filter(i => i.category === filter);
    return filtered.slice().sort((a, b) => {
      const da = a.expiryDate ? daysUntil(a.expiryDate) : Infinity;
      const db2 = b.expiryDate ? daysUntil(b.expiryDate) : Infinity;
      if (da !== db2) return da - db2;
      return a.name.localeCompare(b.name);
    });
  }, [db.items, filter]);

  const openNew = () => { setEditing(null); setFormOpen(true); };
  const openItem = (item: StockItem) => { setEditing(item); setFormOpen(true); };

  const selectFilter = (id: CategoryId) => {
    if (!premium && !isFreeCategory(id)) { setPaywallOpen(true); return; }
    setFilter(id === filter ? 'all' : id);
  };

  return (
    <View style={st.screen}>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', padding: 12, paddingBottom: 4 }}>
        <Chip label="すべて" on={filter === 'all'} onPress={() => setFilter('all')} />
        {CATEGORIES.map(cat => (
          <Chip key={cat.id}
                label={`${cat.icon} ${cat.label}${!premium && !isFreeCategory(cat.id) ? ' 🔒' : ''}`}
                on={filter === cat.id}
                onPress={() => selectFilter(cat.id)} />
        ))}
      </View>

      <FlatList
        data={items}
        keyExtractor={i => i.id}
        contentContainerStyle={{ padding: 16, paddingBottom: 100 }}
        ListEmptyComponent={
          <Text style={[st.subText, { textAlign: 'center', marginTop: 24 }]}>
            該当する備蓄品がありません。右下の＋から追加できます。
          </Text>
        }
        renderItem={({ item }) => {
          const cat = categoryOf(item.category);
          const warn = item.expiryDate ? daysUntil(item.expiryDate) <= 7 : false;
          const soon = item.expiryDate ? daysUntil(item.expiryDate) <= 30 : false;
          return (
            <Pressable onPress={() => openItem(item)}>
              <Card>
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <Text style={{ fontSize: 16 }}>{cat.icon} </Text>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>{item.name}</Text>
                    <Text style={st.subText}>{item.quantity}{item.unit}{item.memo ? ` ・ ${item.memo}` : ''}</Text>
                  </View>
                  {item.expiryDate && (
                    <Text style={{
                      fontSize: 12.5, fontWeight: '700',
                      color: warn ? colors.danger : soon ? colors.gold : colors.sub,
                    }}>
                      {fmtDate(item.expiryDate)}{'\n'}{daysUntilLabel(item.expiryDate)}
                    </Text>
                  )}
                </View>
              </Card>
            </Pressable>
          );
        }}
      />

      <Pressable onPress={openNew} style={{
        position: 'absolute', right: 20, bottom: 24,
        width: 58, height: 58, borderRadius: 29, backgroundColor: colors.accent,
        alignItems: 'center', justifyContent: 'center',
        shadowColor: '#000', shadowOpacity: 0.2, shadowRadius: 6, shadowOffset: { width: 0, height: 3 },
        elevation: 4,
      }}>
        <Text style={{ color: '#fff', fontSize: 30, lineHeight: 32 }}>＋</Text>
      </Pressable>

      <ItemFormSheet visible={formOpen} item={editing} onClose={() => setFormOpen(false)}
                     onNeedPremium={() => { setFormOpen(false); setPaywallOpen(true); }} />
      <PaywallSheet visible={paywallOpen} onClose={() => setPaywallOpen(false)} />
    </View>
  );
}
