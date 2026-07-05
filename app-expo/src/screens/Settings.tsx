import React, { useState } from 'react';
import { Alert, Linking, Pressable, ScrollView, Text, View } from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import * as DocumentPicker from 'expo-document-picker';
import { useDb, hashPasscode, isPremium, isAdFree } from '../db';
import {
  ADFREE_PRICE, APP_VERSION, FREE_PARTNER_LIMIT, FREE_TRIAL, PREMIUM_PRICE,
  PRIVACY_URL, TERMS_URL, colors,
} from '../config';
import { Card, Field, PrimaryButton, Sheet, SubButton, st } from '../ui';

export function SettingsScreen() {
  const { db, update, replace } = useDb();
  const [paywallOpen, setPaywallOpen] = useState(false);
  const [passOpen, setPassOpen] = useState(false);

  const exportBackup = async () => {
    try {
      const now = Date.now();
      const json = JSON.stringify({ ...db, lastBackup: now }, null, 2);
      const path = FileSystem.cacheDirectory + 'konkatsu-date-memo-backup.json';
      await FileSystem.writeAsStringAsync(path, json);
      update(d => { d.lastBackup = now; });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(path, { mimeType: 'application/json' });
      }
    } catch {
      Alert.alert('書き出しに失敗しました');
    }
  };

  const importBackup = async () => {
    try {
      const res = await DocumentPicker.getDocumentAsync({ type: 'application/json' });
      if (res.canceled || !res.assets?.[0]) return;
      const text = await FileSystem.readAsStringAsync(res.assets[0].uri);
      const data = JSON.parse(text);
      if (!data || !Array.isArray(data.partners)) throw new Error('bad file');
      Alert.alert('バックアップを読み込む',
        `バックアップ（お相手${data.partners.length}名）で現在のデータを置き換えますか？`, [
          { text: 'キャンセル', style: 'cancel' },
          { text: '読み込む', onPress: () => replace(data) },
        ]);
    } catch {
      Alert.alert('ファイルを読み込めませんでした');
    }
  };

  const wipe = () => {
    Alert.alert('全データを削除', 'すべてのお相手と記録を削除します。元に戻せません。', [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除する', style: 'destructive',
        onPress: () => replace({
          partners: [], myTopics: [],
          premium: db.premium, adFree: db.adFree, passcode: null,
        }),
      },
    ]);
  };

  const togglePasscode = () => {
    if (db.passcode) {
      Alert.alert('パスコードロックを解除しますか？', '', [
        { text: 'キャンセル', style: 'cancel' },
        { text: '解除する', onPress: () => update(d => { d.passcode = null; }) },
      ]);
    } else {
      setPassOpen(true);
    }
  };

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 60 }}>
        <View style={st.secTitle}><Text style={st.secTitleText}>プラン</Text></View>
        <Card>
          <Row label="⭐ プレミアム" value={isPremium(db) ? '有効' : '未購入 ›'}
               onPress={() => {
                 if (!isPremium(db)) { setPaywallOpen(true); return; }
                 // 買い切りのため購入後は状態表示のみ。テスト期間中だけ解除できる
                 if (FREE_TRIAL) {
                   Alert.alert('プレミアムを無効に戻しますか？（テスト用）', '', [
                     { text: 'キャンセル', style: 'cancel' },
                     { text: '無効にする', onPress: () => update(d => { d.premium = false; }) },
                   ]);
                 }
               }} />
          <Row label="🚫 広告なし"
               value={isPremium(db) ? 'プレミアムに込み' : db.adFree ? '有効' : '未購入 ›'}
               onPress={() => {
                 if (!isAdFree(db)) { setPaywallOpen(true); return; }
                 if (FREE_TRIAL && db.adFree && !isPremium(db)) {
                   Alert.alert('広告なしを無効に戻しますか？（テスト用）', '', [
                     { text: 'キャンセル', style: 'cancel' },
                     { text: '無効にする', onPress: () => update(d => { d.adFree = false; }) },
                   ]);
                 }
               }} />
          {!FREE_TRIAL && (
            <Row label="🔄 購入の復元" value="›"
                 onPress={() => {
                   // 正式リリース時: react-native-iap / RevenueCat の restorePurchases に置き換え
                   Alert.alert('決済の準備中です');
                 }} />
          )}
        </Card>

        <View style={st.secTitle}><Text style={st.secTitleText}>セキュリティ・データ</Text></View>
        <Card>
          <Row label="🔒 パスコードロック" value={db.passcode ? 'オン ›' : 'オフ ›'}
               onPress={togglePasscode} />
          <Row label="📤 バックアップを書き出す" value="›" onPress={exportBackup} />
          <Row label="📥 バックアップを読み込む" value="›" onPress={importBackup} />
          <Row label="🗑 全データを削除" value="" danger onPress={wipe} />
        </Card>
        <Text style={[st.subText, { fontSize: 12.5, marginTop: 4 }]}>
          データはすべてこの端末の中にだけ保存され、外部には送信されません。
          Web版のバックアップファイルもそのまま読み込めます。
        </Text>

        <View style={st.secTitle}><Text style={st.secTitleText}>アプリについて</Text></View>
        <Card>
          <Row label="📄 利用規約" value="›" onPress={() => Linking.openURL(TERMS_URL)} />
          <Row label="🔒 プライバシーポリシー" value="›" onPress={() => Linking.openURL(PRIVACY_URL)} />
        </Card>
        <Text style={[st.subText, { textAlign: 'center', marginTop: 8 }]}>
          婚活デートメモ v{APP_VERSION}
        </Text>
      </ScrollView>
      <PaywallSheet visible={paywallOpen} onClose={() => setPaywallOpen(false)} />
      <PasscodeSheet visible={passOpen} onClose={() => setPassOpen(false)} />
    </View>
  );
}

function Row({ label, value, onPress, danger }: {
  label: string; value: string; onPress: () => void; danger?: boolean;
}) {
  return (
    <Pressable onPress={onPress} style={{
      flexDirection: 'row', alignItems: 'center', paddingVertical: 13,
      borderBottomWidth: 1, borderBottomColor: colors.line,
    }}>
      <Text style={[st.rowText, danger && { color: colors.danger }]}>{label}</Text>
      <View style={{ flex: 1 }} />
      <Text style={st.subText}>{value}</Text>
    </Pressable>
  );
}

// ---- ペイウォール ----

export function PaywallSheet({ visible, onClose, message }: {
  visible: boolean; onClose: () => void; message?: string;
}) {
  const { db, update } = useDb();

  const buyPremium = () => {
    if (FREE_TRIAL) {
      update(d => { d.premium = true; });
      onClose();
      return;
    }
    // 正式リリース時: react-native-iap / RevenueCat で
    // com.kuromakuaikin.datememo.premium を購入
    Alert.alert('決済の準備中です');
  };

  const buyAdFree = () => {
    if (FREE_TRIAL) {
      update(d => { d.adFree = true; });
      onClose();
      return;
    }
    Alert.alert('決済の準備中です');
  };

  return (
    <Sheet visible={visible} onClose={onClose} title="⭐ プレミアム">
      {message ? <Text style={[st.subText, { marginBottom: 10 }]}>{message}</Text> : null}
      <Card>
        <Feature text="💬 話題リスト全カテゴリを解放（距離を縮める・価値観・真剣交際前の確認）" />
        <Feature text="🔍 各話題の「深掘りパターン」（会話の流れの例）も全て見られる" />
        <Feature text={`👥 お相手の登録が無制限に（無料版は${FREE_PARTNER_LIMIT}人まで）`} />
        <Feature text="🚫 広告が永続的に非表示（プレミアムに含まれます）" />
        <Feature text="🔁 買い切りのみ。追加課金・サブスクなし" />
        <Feature text="🔒 データはこれまで通り端末内にのみ保存" />
      </Card>
      <PrimaryButton
        label={FREE_TRIAL ? '⭐ プレミアムを無料で有効化（テスト中）' : `⭐ プレミアムを購入（${PREMIUM_PRICE}）`}
        onPress={buyPremium} />
      {!isAdFree(db) && (
        <SubButton
          label={FREE_TRIAL ? '🚫 広告なしのみを無料で有効化（テスト中）' : `🚫 広告なしのみ（${ADFREE_PRICE}・永続）`}
          onPress={buyAdFree} />
      )}
      <Pressable onPress={onClose} style={{ alignItems: 'center', padding: 14 }}>
        <Text style={st.subText}>あとで</Text>
      </Pressable>
      <View style={{ height: 16 }} />
    </Sheet>
  );
}

function Feature({ text }: { text: string }) {
  return (
    <Text style={[st.rowText, {
      paddingVertical: 7, borderBottomWidth: 1, borderBottomColor: colors.line, fontSize: 14.5,
    }]}>
      {text}
    </Text>
  );
}

// ---- パスコード設定 ----

function PasscodeSheet({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const { update } = useDb();
  const [c1, setC1] = useState('');
  const [c2, setC2] = useState('');

  React.useEffect(() => {
    if (visible) { setC1(''); setC2(''); }
  }, [visible]);

  const save = async () => {
    if (!/^\d{4}$/.test(c1)) { Alert.alert('4桁の数字で入力してください'); return; }
    if (c1 !== c2) { Alert.alert('2回の入力が一致しません'); return; }
    const h = await hashPasscode(c1);
    update(d => { d.passcode = h; });
    onClose();
  };

  return (
    <Sheet visible={visible} onClose={onClose} title="🔒 パスコードを設定">
      <Field label="4桁の数字" value={c1} onChange={setC1} keyboardType="number-pad" />
      <Field label="確認のためもう一度" value={c2} onChange={setC2} keyboardType="number-pad" />
      <Text style={[st.subText, { fontSize: 12.5, marginBottom: 8 }]}>
        ※簡易的な画面ロックです。パスコードを忘れると解除できず、アプリの再インストールが必要になります。
      </Text>
      <PrimaryButton label="設定する" onPress={save} />
      <View style={{ height: 24 }} />
    </Sheet>
  );
}
