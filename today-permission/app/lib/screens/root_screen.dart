import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'home_screen.dart';
import 'reflection_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  bool _signingIn = false;

  Future<void> _retrySignIn() async {
    setState(() => _signingIn = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('接続できませんでした。通信環境をご確認ください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('データの準備ができませんでした'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _signingIn ? null : _retrySignIn,
                child: Text(_signingIn ? '接続中…' : 'もう一度試す'),
              ),
            ],
          ),
        ),
      );
    }

    const screens = [HomeScreen(), ReflectionScreen(), HistoryScreen()];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: '今日'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'ふりかえり'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '履歴'),
        ],
      ),
    );
  }
}
