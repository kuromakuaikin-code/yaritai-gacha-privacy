import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/permission.dart';
import '../services/permission_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PermissionRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('履歴'), centerTitle: true),
      body: StreamBuilder<List<Permission>>(
        stream: repo.watchMonth(_focusedDay),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Permission>[];
          final byDay = <DateTime, List<Permission>>{};
          for (final p in items) {
            final day = PermissionRepository.startOfDay(p.date);
            byDay.putIfAbsent(day, () => []).add(p);
          }
          final selected = byDay[PermissionRepository.startOfDay(_selectedDay)] ?? const <Permission>[];
          return Column(
            children: [
              TableCalendar<Permission>(
                locale: 'ja',
                firstDay: DateTime(2024),
                lastDay: DateTime.now().add(const Duration(days: 366)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                eventLoader: (day) => byDay[PermissionRepository.startOfDay(day)] ?? const [],
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                },
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: selected.isEmpty
                    ? Center(
                        child: Text(
                          'この日の許可はありません',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        itemCount: selected.length,
                        itemBuilder: (context, i) {
                          final p = selected[i];
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
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
