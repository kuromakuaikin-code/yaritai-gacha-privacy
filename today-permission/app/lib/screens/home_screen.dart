import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/permission.dart';
import '../services/permission_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showAddDialog(BuildContext context) async {
    final repo = context.read<PermissionRepository>();
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('今日は何を許す？'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(hintText: '例：昼まで寝ていい、ケーキを食べていい'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('許可する'),
          ),
        ],
      ),
    );
    final trimmed = content?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      await repo.add(trimmed, DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PermissionRepository>();
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日の許可'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Permission>>(
        stream: repo.watchDay(today),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  children: [
                    Text(
                      DateFormat('M月d日 (E)', 'ja').format(today),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items.isEmpty ? '今日は自分に何を許してあげる？' : '許可した自分に ✓ をつけよう',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          '＋ から今日の許可を追加',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final p = items[i];
                          return Dismissible(
                            key: ValueKey(p.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Theme.of(context).colorScheme.errorContainer,
                              child: const Icon(Icons.delete_outline),
                            ),
                            onDismissed: (_) => repo.delete(p.id),
                            child: CheckboxListTile(
                              value: p.isCompleted,
                              onChanged: (v) => repo.setCompleted(p, v ?? false),
                              title: Text(
                                p.content,
                                style: p.isCompleted
                                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
