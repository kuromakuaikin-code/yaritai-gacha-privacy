import React, { useState } from 'react';
import { Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { useDb } from '../db';
import { colors } from '../config';
import { MyTopic, uid } from '../types';
import { Card, Field, PrimaryButton, Sheet, SubButton, st } from '../ui';
import { GachaSheet } from './Topics';

export function MyTopicsScreen() {
  const { db, update } = useDb();
  const [editing, setEditing] = useState<MyTopic | null>(null);
  const [adding, setAdding] = useState(false);
  const [gachaOpen, setGachaOpen] = useState(false);
  const [openId, setOpenId] = useState<string | null>(null);

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 120 }}>
        <Text style={[st.subText, { marginBottom: 12 }]}>
          「今度これを話したい」「次に聞くこと」を自由にメモ。お相手ごとの話題チェック・デート前カンペ・話題ガチャにも自動で入ります。
        </Text>
        {db.myTopics.length === 0 ? (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <Text style={{ fontSize: 44 }}>📝</Text>
            <Text style={[st.subText, { textAlign: 'center', marginTop: 8 }]}>
              まだメモがありません。{'\n'}右下の「＋」から追加しましょう。
            </Text>
          </View>
        ) : (
          <Card>
            {db.myTopics.map(t => (
              <View key={t.id}
                    style={{ borderBottomWidth: 1, borderBottomColor: colors.line, paddingVertical: 11 }}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  <Pressable style={{ flex: 1 }}
                             onPress={() => t.note && setOpenId(openId === t.id ? null : t.id)}>
                    <Text style={{ fontSize: 15.5, color: colors.text }}>{t.text}</Text>
                  </Pressable>
                  <Pressable onPress={() => setEditing(t)} hitSlop={8}>
                    <Text style={{ color: colors.accentDark, fontWeight: '700', fontSize: 13 }}>
                      編集
                    </Text>
                  </Pressable>
                  {t.note ? (
                    <Pressable onPress={() => setOpenId(openId === t.id ? null : t.id)} hitSlop={8}>
                      <Text style={{ color: colors.sub, fontSize: 12 }}>
                        {openId === t.id ? '▲' : '▼'}
                      </Text>
                    </Pressable>
                  ) : null}
                </View>
                {openId === t.id && t.note ? (
                  <View style={{
                    marginTop: 8, backgroundColor: colors.accentSoft,
                    borderRadius: 10, padding: 10,
                  }}>
                    <Text style={{ fontSize: 14, color: colors.text }}>📝 {t.note}</Text>
                  </View>
                ) : null}
              </View>
            ))}
          </Card>
        )}
        {db.myTopics.length > 0 && (
          <SubButton label="🎲 話題ガチャで3つ引く" onPress={() => setGachaOpen(true)} />
        )}
      </ScrollView>

      <Pressable onPress={() => setAdding(true)} style={{
        position: 'absolute', right: 20, bottom: 24,
        width: 58, height: 58, borderRadius: 29,
        backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center',
        shadowColor: colors.accentDark, shadowOpacity: 0.4, shadowRadius: 8,
        shadowOffset: { width: 0, height: 4 }, elevation: 5,
      }}>
        <Text style={{ color: '#fff', fontSize: 30, marginTop: -2 }}>＋</Text>
      </Pressable>

      <MyTopicFormSheet visible={adding || editing !== null}
                        topic={editing}
                        onClose={() => { setAdding(false); setEditing(null); }} />
      <GachaSheet visible={gachaOpen} partnerId={null} onClose={() => setGachaOpen(false)} />
    </View>
  );
}

function MyTopicFormSheet({ visible, topic, onClose }: {
  visible: boolean; topic: MyTopic | null; onClose: () => void;
}) {
  const { db, update } = useDb();
  const [text, setText] = useState('');
  const [note, setNote] = useState('');

  React.useEffect(() => {
    if (!visible) return;
    setText(topic?.text ?? '');
    setNote(topic?.note ?? '');
  }, [visible, topic]);

  const save = () => {
    const v = text.trim();
    if (!v) { Alert.alert('話したいことを入力してください'); return; }
    update(d => {
      if (topic) {
        const t = d.myTopics.find(x => x.id === topic.id);
        if (t) { t.text = v; t.note = note.trim(); }
      } else {
        d.myTopics.push({ id: uid(), text: v, note: note.trim() });
      }
    });
    onClose();
  };

  const move = (dir: -1 | 1) => {
    if (!topic) return;
    update(d => {
      const i = d.myTopics.findIndex(x => x.id === topic.id);
      const j = i + dir;
      if (i < 0 || j < 0 || j >= d.myTopics.length) return;
      [d.myTopics[i], d.myTopics[j]] = [d.myTopics[j], d.myTopics[i]];
    });
  };

  const remove = () => {
    if (!topic) return;
    Alert.alert('MY話題を削除', `「${topic.text}」を削除しますか？`, [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除する', style: 'destructive',
        onPress: () => {
          update(d => { d.myTopics = d.myTopics.filter(x => x.id !== topic.id); });
          onClose();
        },
      },
    ]);
  };

  return (
    <Sheet visible={visible} onClose={onClose} title={topic ? 'MY話題を編集' : 'MY話題を追加'}>
      <Field label="話したいこと *" value={text} onChange={setText}
             placeholder="例：次の連休の予定を聞く" />
      <Field label="メモ・聞き方（任意）" value={note} onChange={setNote} multiline
             placeholder="例：「連休どこか行きます？」→ 空いてたら水族館に誘う" />
      {topic && (
        <View style={{ flexDirection: 'row', gap: 10 }}>
          <View style={{ flex: 1 }}><SubButton label="↑ 上へ" onPress={() => move(-1)} /></View>
          <View style={{ flex: 1 }}><SubButton label="↓ 下へ" onPress={() => move(1)} /></View>
        </View>
      )}
      <PrimaryButton label="保存" onPress={save} />
      {topic && (
        <Pressable onPress={remove} style={{ alignItems: 'center', padding: 14 }}>
          <Text style={{ color: colors.danger }}>この話題を削除</Text>
        </Pressable>
      )}
      <View style={{ height: 24 }} />
    </Sheet>
  );
}
