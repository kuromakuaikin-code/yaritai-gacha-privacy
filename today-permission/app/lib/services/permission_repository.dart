import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/permission.dart';

/// Firestore の users/{uid}/permissions 配下を読み書きするリポジトリ。
/// 匿名認証の uid でユーザーごとにデータを分離する。
class PermissionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('permissions');
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Stream<List<Permission>> watchDay(DateTime day) {
    final start = startOfDay(day);
    final end = start.add(const Duration(days: 1));
    return _watchRange(start, end);
  }

  Stream<List<Permission>> watchMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _watchRange(start, end);
  }

  Stream<List<Permission>> _watchRange(DateTime start, DateTime end) {
    return _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(Permission.fromDoc).toList());
  }

  Future<void> add(String content, DateTime date) {
    return _col.add({
      'content': content,
      'isCompleted': false,
      'reflectionScore': 0,
      'reflectionText': '',
      'date': Timestamp.fromDate(date),
    });
  }

  Future<void> setCompleted(Permission p, bool value) {
    return _col.doc(p.id).update({'isCompleted': value});
  }

  Future<void> saveReflection(Permission p, int score, String text) {
    return _col.doc(p.id).update({
      'reflectionScore': score,
      'reflectionText': text,
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
