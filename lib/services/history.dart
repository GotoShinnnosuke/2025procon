import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_menu.dart';

class HistoryRepository {
  static const _kLastExercises = 'last_exercises_v1';

  Future<void> saveLastExercises(List<ExerciseItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final jsonList = items.map((e) => _exerciseToMap(e)).toList();
    await sp.setString(_kLastExercises, jsonEncode({'exercises': jsonList}));
  }

  Future<List<ExerciseItem>> getLastExercises() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kLastExercises);
    if (raw == null) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = (map['exercises'] as List?) ?? const [];
      return list
          .map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _exerciseToMap(ExerciseItem e) => {
        'name': e.name,
        'sets': e.sets,
        'repsOrSeconds': e.repsOrSeconds,
        'rest': e.rest,
        'notes': e.notes,
        'tips': e.tips,
        'steps': e.steps,
      };
}

