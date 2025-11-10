import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/training_menu.dart';
import 'training_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingLogFirestoreRepository {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('trainingLogs');

  Future<String?> _userId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('user_id');
  }

  Map<String, dynamic> _toDoc(TrainingLog log, {String? userId}) {
    return {
      'exerciseName': log.exerciseName,
      'userId': userId ?? log.userId,
      'sets': log.sets,
      'repsOrSeconds': log.repsOrSeconds,
      'rest': log.rest,
      'notes': log.notes,
      'calories': log.calories,
      'favoriteAtTime': log.favoriteAtTime,
      'completedAt': Timestamp.fromDate(log.completedAt),
      'deleted': log.deleted,
    };
  }

  Future<void> add(TrainingLog log) async {
    // Firebase初期化が未完了の場合は例外が飛ぶため呼び出し側でcatch推奨
    String? uid = log.userId;
    uid ??= FirebaseAuth.instance.currentUser?.uid;
    uid ??= await _userId();
    await _col.doc(log.id).set(_toDoc(log, userId: uid));
  }

  Future<void> softDelete(String id) async {
    await _col.doc(id).update({'deleted': true});
  }

  Future<List<TrainingLog>> fetch({bool includeDeleted = false}) async {
    Query q = _col.orderBy('completedAt', descending: true);
    if (!includeDeleted) {
      q = q.where('deleted', isEqualTo: false);
    }
    final snap = await q.get();
    return snap.docs.map((d) {
      final Map<String, dynamic> j = d.data() as Map<String, dynamic>;
      return TrainingLog(
        id: d.id,
        exerciseName: (j['exerciseName'] ?? '').toString(),
        userId: j['userId']?.toString(),
        sets: j['sets'] is int ? j['sets'] as int : int.tryParse('${j['sets']}'),
        repsOrSeconds: j['repsOrSeconds']?.toString(),
        rest: j['rest']?.toString(),
        notes: j['notes']?.toString(),
        calories: j['calories'] is int ? j['calories'] as int : int.tryParse('${j['calories']}'),
        favoriteAtTime: j['favoriteAtTime'] == true,
        completedAt: (j['completedAt'] is Timestamp)
            ? (j['completedAt'] as Timestamp).toDate()
            : DateTime.now(),
        deleted: j['deleted'] == true,
      );
    }).toList();
  }
}
