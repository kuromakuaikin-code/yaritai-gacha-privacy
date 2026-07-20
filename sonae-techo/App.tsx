import React from 'react';
import { Text, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { DbProvider, useDb, isAdFree } from './src/db';
import { ADMOB_BANNER_UNIT_ID, ADS_ENABLED, colors } from './src/config';
import { HomeScreen } from './src/screens/Home';
import { ListScreen } from './src/screens/List';
import { SettingsScreen } from './src/screens/Settings';

const Tab = createBottomTabNavigator();

function Tabs() {
  return (
    <Tab.Navigator screenOptions={{
      tabBarActiveTintColor: colors.accentDark,
      tabBarInactiveTintColor: colors.sub,
      headerTintColor: colors.accentDark,
    }}>
      <Tab.Screen name="HomeTab" component={HomeScreen}
                  options={{
                    title: 'そなえ手帳', tabBarLabel: 'ホーム',
                    tabBarIcon: ({ focused }) => <TabEmoji e="🏠" focused={focused} />,
                  }} />
      <Tab.Screen name="ListTab" component={ListScreen}
                  options={{
                    title: '備蓄一覧', tabBarLabel: '一覧',
                    tabBarIcon: ({ focused }) => <TabEmoji e="📋" focused={focused} />,
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

// AdMob（react-native-google-mobile-ads）は EAS Build でのみ存在する。
// Expo Go では require が失敗するため null になり、サンプル枠を表示する。
let AdsLib: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  AdsLib = require('react-native-google-mobile-ads');
} catch {
  AdsLib = null;
}

function AdBar() {
  const { db } = useDb();
  if (!ADS_ENABLED || isAdFree(db)) return null;

  if (AdsLib?.BannerAd) {
    const unitId = ADMOB_BANNER_UNIT_ID || AdsLib.TestIds.BANNER;
    return (
      <View style={{
        backgroundColor: colors.card,
        borderTopWidth: 1, borderTopColor: colors.line,
        alignItems: 'center',
      }}>
        <AdsLib.BannerAd
          unitId={unitId}
          size={AdsLib.BannerAdSize.ANCHORED_ADAPTIVE_BANNER}
          requestOptions={{ requestNonPersonalizedAdsOnly: true }}
        />
      </View>
    );
  }

  return (
    <View style={{
      height: 50, backgroundColor: colors.card,
      borderTopWidth: 1, borderTopColor: colors.line,
      flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, gap: 8,
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

export default function App() {
  return (
    <SafeAreaProvider>
      <DbProvider>
        <NavigationContainer>
          <Tabs />
        </NavigationContainer>
        <AdBar />
        <StatusBar style="auto" />
      </DbProvider>
    </SafeAreaProvider>
  );
}
