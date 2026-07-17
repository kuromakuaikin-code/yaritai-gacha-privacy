import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/permission.dart';
import '../services/permission_repository.dart';

class ReflectionScreen extends StatelessWidget {
  const ReflectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PermissionRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('ふりかえり'), centerTitle: true),
      body: StreamBuilder<List<Permission>>(
        stream: repo.watchDay(DateTime.now()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Text(
                '今日の許可がまだありません',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                leading: Icon(
                  p.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: p.isCompleted ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(p.content),
                subtitle: p.reflectionScore > 0 || p.reflectionText.isNotEmpty
                    ? Text(
                        '${p.reflectionScore > 0 ? '★' * p.reflectionScore : ''}'
                        '${p.reflectionScore > 0 && p.reflectionText.isNotEmpty ? ' ' : ''}'
                        '${p.reflectionText}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text('タップしてふりかえりを書く'),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ReflectionSheet(permission: p, repo: repo),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReflectionSheet extends StatefulWidget {
  const _ReflectionSheet({required this.permission, required this.repo});

  final Permission permission;
  final PermissionRepository repo;

  @override
  State<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends State<_ReflectionSheet> {
  late int _score = widget.permission.reflectionScore;
  late final TextEditingController _controller =
      TextEditingController(text: widget.permission.reflectionText);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repo.saveReflection(widget.permission, _score, _controller.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.permission.content,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('許してよかった度', style: Theme.of(context).textTheme.bodySmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _score;
                return IconButton(
                  onPressed: () => setState(() => _score = i + 1),
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: filled ? Theme.of(context).colorScheme.primary : null,
                    size: 32,
                  ),
                );
              }),
            ),
            TextField(
              controller: _controller,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ひとことメモ',
                hintText: '許してみてどうだった？',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存する'),
            ),
          ],
        ),
      ),
    );
  }
}
