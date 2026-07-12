import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { RouteProp, useRoute } from '@react-navigation/native';
import { useDb, isPremium, allTopicCount, talkedCount, untalkedItems, UntalkedItem } from '../db';
import { FREE_TRIAL, PREMIUM_PRICE, colors } from '../config';
import { TOPIC_CATEGORIES, TopicFlow } from '../topics';
import { Card, PrimaryButton, Sheet, SubButton, st } from '../ui';
import { PaywallSheet } from './Settings';
import { RootStackParams } from './Partners';

// ---- 会話フロー表示 ----

export function FlowBox({ flow, premium, onLockedTap }: {
  flow: TopicFlow; premium: boolean; onLockedTap?: () => void;
}) {
  return (
    <View style={{ marginTop: 8, gap: 7 }}>
      <View style={{
        backgroundColor: colors.accentSoft, borderRadius: 12, borderBottomLeftRadius: 4,
        padding: 10, alignSelf: 'flex-start', maxWidth: '92%',
      }}>
        <Text style={{ fontSize: 14.5, color: colors.text }}>💬 {flow.q}</Text>
      </View>
      <View style={{
        backgroundColor: colors.graySoft, borderRadius: 12, borderBottomRightRadius: 4,
        padding: 10, alignSelf: 'flex-end', maxWidth: '92%',
      }}>
        <Text style={{ fontSize: 14.5, color: colors.sub }}>🗣 「{flow.a}」</Text>
      </View>
      <Text style={{ fontSize: 12.5, fontWeight: '700', color: colors.sub }}>
        ↩ 答えに合わせて聞き返す
      </Text>
      {flow.d.map(([tag, text], i) => (
        <View key={i} style={{ flexDirection: 'row', gap: 8, alignItems: 'flex-start' }}>
          <View style={{
            backgroundColor: colors.blueSoft, borderRadius: 999,
            paddingHorizontal: 9, paddingVertical: 2, marginTop: 2,
          }}>
            <Text style={{ color: colors.blue, fontSize: 11.5, fontWeight: '700' }}>{tag}</Text>
          </View>
          <Text style={{ fontSize: 14.5, color: colors.text, flex: 1 }}>{text}</Text>
        </View>
      ))}
      {premium ? (
        (flow.good || flow.flat || flow.ng) && (
          <View style={{ marginTop: 4, gap: 6 }}>
            {flow.good && <ReactionRow icon="🌱" label="盛り上がったら" text={flow.good} />}
            {flow.flat && <ReactionRow icon="🍃" label="反応がうすい時" text={flow.flat} />}
            {flow.ng && <ReactionRow icon="⚠" label="これは避けたい" text={flow.ng} />}
          </View>
      )) : (
        <Pressable onPress={onLockedTap} style={{
          marginTop: 4, backgroundColor: colors.accentSoft, borderRadius: 10,
          paddingVertical: 9, paddingHorizontal: 10, alignItems: 'center',
        }}>
          <Text style={{ color: colors.accentDark, fontSize: 13, fontWeight: '700' }}>
            ⭐ 反応別パターンはプレミアムで見られます
          </Text>
        </Pressable>
      )}
    </View>
  );
}

function ReactionRow({ icon, label, text }: { icon: string; label: string; text: string }) {
  return (
    <View style={{
      backgroundColor: colors.graySoft, borderRadius: 10, padding: 9,
    }}>
      <Text style={{ fontSize: 12, fontWeight: '700', color: colors.sub, marginBottom: 2 }}>
        {icon} {label}
      </Text>
      <Text style={{ fontSize: 13.5, color: colors.text }}>{text}</Text>
    </View>
  );
}

function TopicRow({ id, title, flow, note, checked, onToggle, premium, onLockedTap }: {
  id: string; title: string; flow?: TopicFlow; note?: string;
  checked?: boolean; onToggle?: () => void;
  premium?: boolean; onLockedTap?: () => void;
}) {
  const [open, setOpen] = useState(false);
  const expandable = !!flow || !!note;
  return (
    <View style={{ borderBottomWidth: 1, borderBottomColor: colors.line, paddingVertical: 11 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        {onToggle && (
          <Pressable onPress={onToggle} hitSlop={8}>
            <Text style={{ fontSize: 22, color: checked ? colors.accent : '#c9bfc4' }}>
              {checked ? '☑' : '☐'}
            </Text>
          </Pressable>
        )}
        <Pressable style={{ flex: 1 }} onPress={() => expandable && setOpen(!open)}>
          <Text style={{
            fontSize: 15.5,
            color: checked ? colors.sub : colors.text,
            textDecorationLine: checked ? 'line-through' : 'none',
          }}>
            {title}
          </Text>
        </Pressable>
        {expandable && (
          <Pressable onPress={() => setOpen(!open)} hitSlop={10}>
            <Text style={{ color: colors.sub, fontSize: 12 }}>{open ? '▲' : '▼'}</Text>
          </Pressable>
        )}
      </View>
      {open && flow && <FlowBox flow={flow} premium={!!premium} onLockedTap={onLockedTap} />}
      {open && note ? (
        <View style={{
          marginTop: 8, backgroundColor: colors.accentSoft, borderRadius: 10, padding: 10,
        }}>
          <Text style={{ fontSize: 14, color: colors.text }}>📝 {note}</Text>
        </View>
      ) : null}
    </View>
  );
}

// ---- 話題タブ（ブラウズ）＆ お相手別チェックリスト ----

export function TopicsScreen() {
  return <TopicsBody partnerId={null} />;
}

export function ChecklistScreen() {
  const route = useRoute<RouteProp<RootStackParams, 'Checklist'>>();
  return <TopicsBody partnerId={route.params.partnerId} />;
}

function TopicsBody({ partnerId }: { partnerId: string | null }) {
  const { db, update } = useDb();
  const premium = isPremium(db);
  const partner = partnerId ? db.partners.find(p => p.id === partnerId) ?? null : null;
  const [paywallOpen, setPaywallOpen] = useState(false);
  const [gachaOpen, setGachaOpen] = useState(false);

  const toggle = (topicId: string) => {
    if (!partner) return;
    update(d => {
      const p = d.partners.find(x => x.id === partner.id);
      if (!p) return;
      if (p.talked[topicId]) delete p.talked[topicId];
      else p.talked[topicId] = true;
    });
  };

  const done = partner ? talkedCount(db, partner) : 0;
  const total = allTopicCount(db);
  const lockedCount = TOPIC_CATEGORIES.filter(c => !c.free).reduce((n, c) => n + c.topics.length, 0);

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 60 }}>
        {partner && (
          <Card>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Text style={{ fontWeight: '700', color: colors.text }}>{partner.name}</Text>
              <View style={{ flex: 1 }} />
              <Text style={st.subText}>
                <Text style={{ color: colors.accentDark, fontWeight: '700' }}>{done}</Text> / {total} 話した
              </Text>
            </View>
            <View style={{
              height: 6, borderRadius: 999, backgroundColor: colors.graySoft,
              marginTop: 8, overflow: 'hidden',
            }}>
              <View style={{
                width: `${total ? Math.round((done / total) * 100) : 0}%`,
                height: 6, backgroundColor: colors.accent, borderRadius: 999,
              }} />
            </View>
          </Card>
        )}

        {!premium && (
          <Pressable onPress={() => setPaywallOpen(true)}>
            <Card style={{ backgroundColor: colors.accentDark, borderColor: colors.accentDark }}>
              <Text style={{ color: '#fff', fontWeight: '700', fontSize: 16 }}>
                ⭐ プレミアムで話題を全種類解放
              </Text>
              <Text style={{ color: '#ffe3ec', fontSize: 13, marginTop: 2 }}>
                残り{lockedCount}種の話題＋反応別パターン＋お相手無制限＋広告なしを解放｜{FREE_TRIAL ? '今なら無料' : `${PREMIUM_PRICE} 買い切り`}
              </Text>
            </Card>
          </Pressable>
        )}

        <SubButton label="🎲 話題ガチャで3つ引く" onPress={() => setGachaOpen(true)} />

        {partner && db.myTopics.length > 0 && (
          <>
            <View style={st.secTitle}>
              <Text style={st.secTitleText}>📝 MY話題リスト</Text>
            </View>
            <Card>
              {db.myTopics.map(t => (
                <TopicRow key={t.id} id={t.id} title={t.text}
                          note={t.note || undefined}
                          checked={!!partner.talked[t.id]}
                          onToggle={() => toggle(t.id)} />
              ))}
            </Card>
          </>
        )}

        {TOPIC_CATEGORIES.map(cat => {
          const unlocked = cat.free || premium;
          return (
            <View key={cat.name}>
              <View style={st.secTitle}>
                <Text style={st.secTitleText}>{cat.name}</Text>
                {!unlocked && (
                  <Text style={{ color: colors.gold, fontSize: 11, fontWeight: '700', marginLeft: 6 }}>
                    ⭐ プレミアム
                  </Text>
                )}
              </View>
              <Card>
                {unlocked ? (
                  cat.topics.map(t => (
                    <TopicRow key={t.id} id={t.id} title={t.title} flow={t.flow}
                              checked={partner ? !!partner.talked[t.id] : undefined}
                              onToggle={partner ? () => toggle(t.id) : undefined}
                              premium={premium} onLockedTap={() => setPaywallOpen(true)} />
                  ))
                ) : (
                  <Pressable onPress={() => setPaywallOpen(true)}
                             style={{ alignItems: 'center', paddingVertical: 20 }}>
                    <Text style={{ color: colors.accentDark, fontWeight: '700', fontSize: 15 }}>
                      🔒 タップして解放（{cat.topics.length}話題）
                    </Text>
                    <Text style={[st.subText, { marginTop: 3 }]}>
                      {FREE_TRIAL ? 'テスト期間中は無料' : `${PREMIUM_PRICE} 買い切り`}
                    </Text>
                  </Pressable>
                )}
              </Card>
            </View>
          );
        })}
      </ScrollView>
      <PaywallSheet visible={paywallOpen} onClose={() => setPaywallOpen(false)} />
      <GachaSheet visible={gachaOpen} partnerId={partnerId} onClose={() => setGachaOpen(false)} />
    </View>
  );
}

// ---- 話題ガチャ ----

export function GachaSheet({ visible, partnerId, onClose }: {
  visible: boolean; partnerId: string | null; onClose: () => void;
}) {
  const { db } = useDb();
  const [seed, setSeed] = useState(0);

  const picks = useMemo(() => {
    if (!visible) return [] as UntalkedItem[];
    const partner = partnerId ? db.partners.find(p => p.id === partnerId) ?? null : null;
    const pool = untalkedItems(db, partner);
    return [...pool].sort(() => Math.random() - 0.5).slice(0, 3);
    // seed を依存に入れて「もう一回引く」で再抽選
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, seed, partnerId]);

  return (
    <Sheet visible={visible} onClose={onClose} title="🎲 話題ガチャ">
      <Text style={[st.subText, { marginBottom: 10 }]}>
        {partnerId ? 'まだ話していない話題' : '解放中の話題'}からランダムに3つ引きます。
      </Text>
      {picks.length === 0 && (
        <Card><Text style={st.rowText}>引ける話題がありません。全部話しました！🎉</Text></Card>
      )}
      {picks.map(p => (
        <Card key={p.id}>
          <Text style={[st.subText, { fontWeight: '700', fontSize: 13 }]}>
            {p.isMy ? '📝 MY話題' : p.title}
          </Text>
          <Text style={{ fontWeight: '700', color: colors.text, marginTop: 2, fontSize: 15.5 }}>
            💬 {p.q}
          </Text>
          {p.hint && (
            <View style={{ flexDirection: 'row', gap: 8, marginTop: 8, alignItems: 'flex-start' }}>
              <View style={{
                backgroundColor: colors.blueSoft, borderRadius: 999,
                paddingHorizontal: 9, paddingVertical: 2, marginTop: 1,
              }}>
                <Text style={{ color: colors.blue, fontSize: 11.5, fontWeight: '700' }}>
                  {p.hint[0]}
                </Text>
              </View>
              <Text style={{ fontSize: 14, color: colors.text, flex: 1 }}>{p.hint[1]}</Text>
            </View>
          )}
          {p.note ? (
            <Text style={[st.subText, { marginTop: 6 }]}>📝 {p.note}</Text>
          ) : null}
        </Card>
      ))}
      <PrimaryButton label="もう一回引く" onPress={() => setSeed(s => s + 1)} />
      <View style={{ height: 24 }} />
    </Sheet>
  );
}
