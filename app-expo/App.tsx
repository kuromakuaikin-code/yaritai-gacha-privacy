import React, { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';
import { DbProvider, useDb, hashPasscode, isAdFree } from './src/db';
import { ADS_ENABLED, colors } from './src/config';
import { PartnersScreen, RootStackParams } from './src/screens/Partners';
import { BriefScreen, PartnerDetailScreen } from './src/screens/Detail';
import { ChecklistScreen, TopicsScreen } from './src/screens/Topics';
import { MyTopicsScreen } from './src/screens/MyTopics';
import { SettingsScreen } from './src/screens/Settings';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator<RootStackParams>();

function PartnersStack() {
  return (
    <Stack.Navigator screenOptions={{ headerTintColor: colors.accentDark }}>
      <Stack.Screen name="PartnerList" component={PartnersScreen}
                    options={{ title: '婚活デートメモ' }} />
      <Stack.Screen name="PartnerDetail" component={PartnerDetailScreen}
                    options={{ title: 'お相手' }} />
      <Stack.Screen name="Brief" component={BriefScreen}
                    options={{ title: 'デート前カンペ' }} />
      <Stack.Screen name="Checklist" component={ChecklistScreen}
                    options={{ title: '話題チェック' }} />
    </Stack.Navigator>
  );
}

function Tabs() {
  return (
    <Tab.Navigator screenOptions={{
      tabBarActiveTintColor: colors.accentDark,
      tabBarInactiveTintColor: colors.sub,
    }}>
      <Tab.Screen name="PartnersTab" component={PartnersStack}
                  options={{
                    headerShown: false, title: 'お相手',
                    tabBarIcon: ({ focused }) => <TabEmoji e="💐" focused={focused} />,
                  }} />
      <Tab.Screen name="TopicsTab" component={TopicsScreen}
                  options={{
                    title: '話題リスト', tabBarLabel: '話題',
                    tabBarIcon: ({ focused }) => <TabEmoji e="💬" focused={focused} />,
                  }} />
      <Tab.Screen name="MyTab" component={MyTopicsScreen}
                  options={{
                    title: 'MYメモ',
                    tabBarIcon: ({ focused }) => <TabEmoji e="📝" focused={focused} />,
                  }} />
      <Tab.Screen name="SettingsTab" component={SettingsScreen}
                  options={{
                    title: '設定',
                    tabBarIcon: ({ focused }) => <TabEmoji e="⚙️" focused={focused} />,
                  }} />
    </Tab.Navigator>
  );
}

function TabEmoji({ e, focused }: { e: string; focused: boolean }) {
  return <Text style={{ fontSize: 20, opacity: focused ? 1 : 0.45 }}>{e}</Text>;
}

function AdBar() {
  const { db } = useDb();
  const insets = useSafeAreaInsets();
  if (!ADS_ENABLED || isAdFree(db)) return null;
  // 本実装時は react-native-google-mobile-ads の BannerAd に置き換える
  return (
    <View style={{
      height: 50, backgroundColor: colors.card,
      borderTopWidth: 1, borderTopColor: colors.line,
      flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, gap: 8,
      marginBottom: insets.bottom > 0 ? 0 : 0,
    }}>
      <Text style={{
        fontSize: 10.5, fontWeight: '700', color: colors.gray,
        borderWidth: 1, borderColor: colors.line, borderRadius: 4,
        paddingHorizontal: 6, paddingVertical: 1,
      }}>広告</Text>
      <Text style={{ flex: 1, fontSize: 12.5, color: colors.sub }} numberOfLines={1}>
        ここに広告が表示されます（サンプル枠）
      </Text>
    </View>
  );
}

function LockGate({ children }: { children: React.ReactNode }) {
  const { db, loaded } = useDb();
  const [unlocked, setUnlocked] = useState(false);
  const [input, setInput] = useState('');
  const [wrong, setWrong] = useState(false);

  if (!loaded) return <View style={{ flex: 1, backgroundColor: colors.bg }} />;
  if (!db.passcode || unlocked) return <>{children}</>;

  const tap = async (key: string) => {
    if (key === '⌫') { setInput(i => i.slice(0, -1)); return; }
    if (input.length >= 4) return;
    const next = input + key;
    setInput(next);
    if (next.length === 4) {
      const h = await hashPasscode(next);
      if (h === db.passcode) {
        setUnlocked(true);
      } else {
        setWrong(true);
        setTimeout(() => { setWrong(false); setInput(''); }, 400);
      }
    }
  };

  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
  return (
    <View style={{
      flex: 1, backgroundColor: colors.bg,
      alignItems: 'center', justifyContent: 'center', gap: 20,
    }}>
      <Text style={{ fontSize: 42 }}>🔒</Text>
      <Text style={{ fontWeight: '700', color: wrong ? colors.danger : colors.text }}>
        {wrong ? 'パスコードが違います' : 'パスコードを入力'}
      </Text>
      <View style={{ flexDirection: 'row', gap: 14 }}>
        {[0, 1, 2, 3].map(i => (
          <View key={i} style={{
            width: 14, height: 14, borderRadius: 7,
            borderWidth: 2, borderColor: colors.accent,
            backgroundColor: i < input.length ? colors.accent : 'transparent',
          }} />
        ))}
      </View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', width: 3 * 84, justifyContent: 'center' }}>
        {keys.map((k, i) => (
          <View key={i} style={{ width: 84, height: 76, alignItems: 'center', justifyContent: 'center' }}>
            {k !== '' && (
              <Pressable onPress={() => tap(k)} style={{
                width: 66, height: 64, borderRadius: 33,
                backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line,
                alignItems: 'center', justifyContent: 'center',
              }}>
                <Text style={{ fontSize: 24, fontWeight: '600', color: colors.text }}>{k}</Text>
              </Pressable>
            )}
          </View>
        ))}
      </View>
    </View>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <DbProvider>
        <LockGate>
          <NavigationContainer>
            <Tabs />
          </NavigationContainer>
          <AdBar />
        </LockGate>
        <StatusBar style="auto" />
      </DbProvider>
    </SafeAreaProvider>
  );
}
