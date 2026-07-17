import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/root_screen.dart';
import 'services/permission_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS専用のため ios/Runner/GoogleService-Info.plist から設定を自動読み込み
  await Firebase.initializeApp();
  await initializeDateFormatting('ja');
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } on FirebaseAuthException {
    // オフライン等で失敗した場合は RootScreen 側で再試行を促す
  }
  runApp(const TodayPermissionApp());
}

class TodayPermissionApp extends StatelessWidget {
  const TodayPermissionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<PermissionRepository>(
      create: (_) => PermissionRepository(),
      child: MaterialApp(
        title: '今日の許可',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
          useMaterial3: true,
        ),
        home: const RootScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
