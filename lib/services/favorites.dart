import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_menu.dart';

class FavoritesRepository {
  static const _kFavExercises = 'favorite_exercises_v1';

  Future<List<ExerciseItem>> getFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFavExercises);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['exercises'] as List?) ?? const [];
      return list
          .map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<ExerciseItem> list) async {
    final sp = await SharedPreferences.getInstance();
    final jsonList = list
        .map((e) => {
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
            })
        .toList();
    await sp.setString(_kFavExercises, jsonEncode({'exercises': jsonList}));
  }

  Future<bool> toggle(ExerciseItem item) async {
    final list = await getFavorites();
    final idx = list.indexWhere((e) => e.name == item.name);
    if (idx >= 0) {
      list.removeAt(idx);
      await _save(list);
      return false;
    } else {
      list.add(item);
      await _save(list);
      return true;
    }
  }

  Future<bool> isFavorite(ExerciseItem item) async {
    final list = await getFavorites();
    return list.any((e) => e.name == item.name);
  }
}

