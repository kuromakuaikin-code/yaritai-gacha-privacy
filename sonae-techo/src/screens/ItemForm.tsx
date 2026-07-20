import React, { useEffect, useState } from 'react';
import { Alert, Text, View } from 'react-native';
import { useDb, isPremium } from '../db';
import { CATEGORIES, categoryOf, isFreeCategory } from '../categories';
import { CategoryId, StockItem, uid } from '../types';
import { colors } from '../config';
import { Chip, Field, PrimaryButton, Sheet, Stepper, SubButton, st } from '../ui';

const validDate = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s);

export function ItemFormSheet({ visible, item, onClose, onNeedPremium }: {
  visible: boolean;
  item: StockItem | null;
  onClose: () => void;
  onNeedPremium: () => void;
}) {
  const { db, update } = useDb();
  const premium = isPremium(db);

  const [category, setCategory] = useState<CategoryId>('water');
  const [name, setName] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [expiryDate, setExpiryDate] = useState('');
  const [memo, setMemo] = useState('');

  useEffect(() => {
    if (!visible) return;
    setCategory(item?.category ?? 'water');
    setName(item?.name ?? '');
    setQuantity(item?.quantity ?? 1);
    setExpiryDate(item?.expiryDate ?? '');
    setMemo(item?.memo ?? '');
  }, [visible, item]);

  const pickCategory = (id: CategoryId) => {
    if (!premium && !isFreeCategory(id)) { onNeedPremium(); return; }
    setCategory(id);
  };

  const save = () => {
    if (!name.trim()) { Alert.alert('品名を入力してください'); return; }
    if (expiryDate && !validDate(expiryDate)) {
      Alert.alert('期限は YYYY-MM-DD 形式で入力してください（未定なら空欄でOK）'); return;
    }
    const unit = categoryOf(category).unit;
    update(d => {
      if (item) {
        const t = d.items.find(x => x.id === item.id);
        if (t) {
          Object.assign(t, {
            name: name.trim(), category, quantity, unit,
            expiryDate: expiryDate || undefined, memo, updatedAt: Date.now(),
          });
        }
      } else {
        d.items.push({
          id: uid(), name: name.trim(), category, quantity, unit,
          expiryDate: expiryDate || undefined, memo,
          createdAt: Date.now(), updatedAt: Date.now(),
        });
      }
    });
    onClose();
  };

  const remove = () => {
    if (!item) return;
    Alert.alert('削除しますか？', item.name, [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除する', style: 'destructive',
        onPress: () => { update(d => { d.items = d.items.filter(x => x.id !== item.id); }); onClose(); },
      },
    ]);
  };

  return (
    <Sheet visible={visible} onClose={onClose} title={item ? '備蓄品を編集' : '備蓄品を追加'}>
      <Text style={st.fieldLabel}>カテゴリ</Text>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
        {CATEGORIES.map(cat => {
          const locked = !premium && !isFreeCategory(cat.id);
          return (
            <Chip
              key={cat.id}
              label={`${cat.icon} ${cat.label}${locked ? ' 🔒' : ''}`}
              on={category === cat.id}
              onPress={() => pickCategory(cat.id)}
            />
          );
        })}
      </View>

      <Field label="品名" value={name} onChange={setName} placeholder="例：飲料水 2L×6本" />
      <Stepper label={`数量（${categoryOf(category).unit}）`} value={quantity}
               onChange={setQuantity} min={0} max={999} />
      <Field label="期限（YYYY-MM-DD・任意）" value={expiryDate} onChange={setExpiryDate}
             placeholder="例：2026-12-31" />
      <Field label="メモ（任意）" value={memo} onChange={setMemo}
             placeholder="収納場所など" multiline />

      <PrimaryButton label="保存する" onPress={save} />
      {item && <SubButton label="この備蓄品を削除" onPress={remove} />}
      <View style={{ height: 20 }} />
    </Sheet>
  );
}
