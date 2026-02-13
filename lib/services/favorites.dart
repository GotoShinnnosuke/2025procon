import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/training_menu.dart';

/// Firestore にお気に入り種目を保存/取得するリポジトリ。
class FavoritesRepository {
  static const _maxFavorites = 5;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites');

  Map<String, dynamic> _toMap(ExerciseItem e, {required bool isFavorite}) {
    return {
      'name': e.name,
      'sets': e.sets,
      'repsOrSeconds': e.repsOrSeconds,
      'rest': e.rest,
      'notes': e.notes,
      'tips': e.tips,
      'steps': e.steps,
      'calories': e.calories,
      'imageUrl': e.imageUrl,
      'videoUrl': e.videoUrl,
      'loadLevel': e.loadLevel,
      'isFavorite': isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<List<ExerciseItem>> getFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _col(uid).where('isFavorite', isEqualTo: true).get();
    return snap.docs.map((d) => ExerciseItem.fromJson(d.data())).toList();
  }

  Future<bool> isFavorite(ExerciseItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _col(uid).doc(item.name).get();
    return (doc.data()?['isFavorite'] == true);
  }

  /// 既にあればフラグ反転、なければ追加。お気に入りは最大5件まで。
  /// true: お気に入り状態になった / false: 解除された
  Future<bool> toggle(ExerciseItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('ログインが必要です');
    }
    final col = _col(uid);
    final ref = col.doc(item.name);
    final doc = await ref.get();
    final exists = doc.exists;
    final current = doc.data()?['isFavorite'] == true;

    if (exists && current) {
      await ref.set(
          {'isFavorite': false, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      return false;
    }

    // 追加する場合は件数チェック
    final favCount =
        await col.where('isFavorite', isEqualTo: true).count().get();
    final count = favCount.count ?? 0;
    if (count >= _maxFavorites) {
      throw Exception('お気に入りは最大$_maxFavorites件までです');
    }

    await ref.set(_toMap(item, isFavorite: true), SetOptions(merge: true));
    return true;
  }
}

class PlanFavoritesRepository {
  static const _maxFavorites = 5;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favoritePlans');

  Map<String, dynamic> _toMap(TrainingMenu plan,
      {required bool isFavorite, int? minutes}) {
    return {
      'plan': plan.toJson(),
      'planMinutes': minutes,
      'isFavorite': isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<List<TrainingMenu>> getFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _col(uid).where('isFavorite', isEqualTo: true).get();
    return snap.docs.map((d) {
      final data = d.data();
      final planData = data['plan'] as Map<String, dynamic>? ?? {};
      return TrainingMenu.fromJson(planData);
    }).toList();
  }

  Future<bool> isFavorite(TrainingMenu plan) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _col(uid).doc(plan.name).get();
    return (doc.data()?['isFavorite'] == true);
  }

  Future<bool> toggle(TrainingMenu plan, {int? minutes}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('ログインが必要です。');
    }
    final col = _col(uid);
    final ref = col.doc(plan.name);
    final doc = await ref.get();
    final exists = doc.exists;
    final current = doc.data()?['isFavorite'] == true;

    if (exists && current) {
      await ref.set(
          {'isFavorite': false, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      return false;
    }

    final favCount =
        await col.where('isFavorite', isEqualTo: true).count().get();
    final count = favCount.count ?? 0;
    if (count >= _maxFavorites) {
      throw Exception('お気に入りは最大$_maxFavorites件までです');
    }

    await ref.set(_toMap(plan, isFavorite: true, minutes: minutes),
        SetOptions(merge: true));
    return true;
  }
}
