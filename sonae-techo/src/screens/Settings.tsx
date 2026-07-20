import React, { useState } from 'react';
import { Alert, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import * as DocumentPicker from 'expo-document-picker';
import { useDb, isPremium } from '../db';
import { buyProduct, restorePurchases } from '../iap';
import { notificationsAvailable, requestNotificationPermission, syncExpiryNotifications } from '../notifications';
import {
  APP_VERSION, FREE_TRIAL, PREMIUM_PRICE, PREMIUM_PRODUCT_ID, PRIVACY_URL, TERMS_URL, colors,
} from '../config';
import { Card, PrimaryButton, Sheet, Stepper, st } from '../ui';

export function SettingsScreen() {
  const { db, update, replace } = useDb();
  const [paywallOpen, setPaywallOpen] = useState(false);
  const premium = isPremium(db);

  const toggleNotify = async (next: boolean) => {
    if (next) {
      const ok = await requestNotificationPermission();
      if (!ok) {
        Alert.alert('通知が許可されていません', '端末の設定アプリから通知を許可してください');
        return;
      }
    }
    update(d => { d.notifyEnabled = next; });
    await syncExpiryNotifications(db.items, next);
  };

  const exportBackup = () => {
    Alert.alert(
      'データを書き出す',
      'このあと開く画面で「ファイルに保存」を選び、iCloud Drive に保存するのがおすすめです。\n\n保存したファイルがあれば、機種変更やアプリを入れ直したときに「データを読み込む」で元どおりに復元できます。',
      [
        { text: 'キャンセル', style: 'cancel' },
        { text: '書き出す', onPress: doExport },
      ],
    );
  };

  const doExport = async () => {
    try {
      const json = JSON.stringify(db, null, 2);
      const path = FileSystem.cacheDirectory + 'sonae-techo-backup.json';
      await FileSystem.writeAsStringAsync(path, json);
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
      if (!data || !Array.isArray(data.items)) throw new Error('bad file');
      Alert.alert('データを読み込む',
        `保存したデータ（備蓄品${data.items.length}件）で、今のアプリの中身を置き換えます。よろしいですか？`, [
          { text: 'キャンセル', style: 'cancel' },
          { text: '読み込む', onPress: () => replace(data) },
        ]);
    } catch {
      Alert.alert('ファイルを読み込めませんでした');
    }
  };

  const wipe = () => {
    Alert.alert('全データを削除', 'すべての備蓄品の登録を削除します。元に戻せません。', [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除する', style: 'destructive',
        onPress: () => replace({
          items: [], householdSize: db.householdSize, targetDays: db.targetDays, premium: db.premium,
        }),
      },
    ]);
  };

  return (
    <View style={st.screen}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 60 }}>
        <View style={st.secTitle}><Text style={st.secTitleText}>家族構成と目標</Text></View>
        <Card>
          <Stepper label="家族の人数" value={db.householdSize} min={1} max={12}
                   onChange={v => update(d => { d.householdSize = v; })} />
          <Stepper label="目標備蓄日数（一般的な目安は7日）" value={db.targetDays} min={1} max={30}
                   onChange={v => update(d => { d.targetDays = v; })} />
        </Card>

        <View style={st.secTitle}><Text style={st.secTitleText}>プラン</Text></View>
        <Card>
          <Row label="⭐ プレミアム" value={premium ? '有効' : '未購入 ›'}
               onPress={() => {
                 if (!premium) { setPaywallOpen(true); return; }
                 if (FREE_TRIAL) {
                   Alert.alert('プレミアムを無効に戻しますか？（テスト用）', '', [
                     { text: 'キャンセル', style: 'cancel' },
                     { text: '無効にする', onPress: () => update(d => { d.premium = false; }) },
                   ]);
                 }
               }} />
          {!FREE_TRIAL && (
            <Row label="🔄 購入の復元" value="›"
                 onPress={async () => {
                   const ids = await restorePurchases();
                   if (!ids.includes(PREMIUM_PRODUCT_ID)) {
                     Alert.alert('復元できる購入が見つかりませんでした');
                     return;
                   }
                   update(d => { d.premium = true; });
                   Alert.alert('購入を復元しました');
                 }} />
          )}
        </Card>

        <View style={st.secTitle}><Text style={st.secTitleText}>通知</Text></View>
        <Card>
          <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 6 }}>
            <Text style={[st.rowText, !premium && { color: colors.sub }]}>🔔 期限が近づいたら通知</Text>
            <View style={{ flex: 1 }} />
            <Switch
              value={!!db.notifyEnabled && premium}
              disabled={!premium || !notificationsAvailable()}
              onValueChange={v => (premium ? toggleNotify(v) : setPaywallOpen(true))}
            />
          </View>
          {!premium && (
            <Text style={[st.subText, { fontSize: 12.5 }]}>プレミアムで利用できます</Text>
          )}
        </Card>

        <View style={st.secTitle}><Text style={st.secTitleText}>データのお引っ越し・保険</Text></View>
        <Card>
          <Row label="📤 データを書き出す" value="機種変更・保険用 ›" onPress={exportBackup} />
          <Row label="📥 データを読み込む" value="復元・引っ越し用 ›" onPress={importBackup} />
          <Row label="🗑 全データを削除" value="" danger onPress={wipe} />
        </Card>
        <Text style={[st.subText, { fontSize: 12.5, marginTop: 4 }]}>
          データはこの端末の中にだけ保存され、外部には送信されません。そのため、アプリを削除するとデータも消えます。
          「データを書き出す」でファイルに保存しておくと、機種変更やアプリの入れ直しのときに「データを読み込む」で元に戻せます。
        </Text>

        <View style={st.secTitle}><Text style={st.secTitleText}>アプリについて</Text></View>
        <Card>
          <Row label="📄 利用規約" value="›" onPress={() => Linking.openURL(TERMS_URL)} />
          <Row label="🔒 プライバシーポリシー" value="›" onPress={() => Linking.openURL(PRIVACY_URL)} />
        </Card>
        <Text style={[st.subText, { textAlign: 'center', marginTop: 8 }]}>
          そなえ手帳 v{APP_VERSION}
        </Text>
      </ScrollView>
      <PaywallSheet visible={paywallOpen} onClose={() => setPaywallOpen(false)} />
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

export function PaywallSheet({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const { update } = useDb();

  const buyPremium = async () => {
    if (FREE_TRIAL) {
      update(d => { d.premium = true; });
      onClose();
      return;
    }
    const r = await buyProduct(PREMIUM_PRODUCT_ID);
    if (r.success) {
      update(d => { d.premium = true; });
      onClose();
    } else if (!r.cancelled) {
      Alert.alert('購入できませんでした', r.message ?? '時間をおいて再度お試しください');
    }
  };

  return (
    <Sheet visible={visible} onClose={onClose} title="⭐ プレミアム">
      <Card>
        <Feature text="🔥🧻🔋📦 カセットボンベ・トイレットペーパー・電池・その他カテゴリを解放" />
        <Feature text="🔔 期限が近づいたらローカル通知でお知らせ" />
        <Feature text="🚫 広告が永続的に非表示" />
        <Feature text="🔁 買い切りのみ。追加課金・サブスクなし" />
        <Feature text="🔒 データはこれまで通り端末内にのみ保存" />
      </Card>
      <PrimaryButton
        label={FREE_TRIAL ? '⭐ プレミアムを無料で有効化（テスト中）' : `⭐ プレミアムを購入（${PREMIUM_PRICE}）`}
        onPress={buyPremium} />
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
