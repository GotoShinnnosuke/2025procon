import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_menu.dart';

class TrainingLog {
  final String id;
  final String exerciseName;
  final String? userId;
  final int? sets;
  final String? repsOrSeconds;
  final String? rest;
  final String? notes;
  final int? calories;
  final String? imageBase64;
  final String? imageUrl;
  final String? loadLevel;
  final bool favoriteAtTime;
  final DateTime completedAt;
  final bool deleted;

  TrainingLog({
    required this.id,
    required this.exerciseName,
    required this.completedAt,
    this.userId,
    this.sets,
    this.repsOrSeconds,
    this.rest,
    this.notes,
    this.calories,
    this.imageBase64,
    this.imageUrl,
    this.loadLevel,
    this.favoriteAtTime = false,
    this.deleted = false,
  });

  factory TrainingLog.fromExercise(ExerciseItem item,
      {required bool favorite, String? userId, String? imageBase64, String? imageUrl, String? id}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final generatedId = id ?? 'log_${ts}_${item.name}';
    return TrainingLog(
      id: generatedId,
      exerciseName: item.name,
      userId: userId,
      sets: item.sets,
      repsOrSeconds: item.repsOrSeconds,
      rest: item.rest,
      notes: item.notes,
      calories: item.calories,
      imageBase64: imageBase64,
      imageUrl: imageUrl ?? item.imageUrl,
      loadLevel: item.loadLevel,
      favoriteAtTime: favorite,
      completedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseName': exerciseName,
        'userId': userId,
        'sets': sets,
        'repsOrSeconds': repsOrSeconds,
        'rest': rest,
        'notes': notes,
        'calories': calories,
        'imageBase64': imageBase64,
        'imageUrl': imageUrl,
        'loadLevel': loadLevel,
        'favoriteAtTime': favoriteAtTime,
        'completedAt': completedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory TrainingLog.fromJson(Map<String, dynamic> j) => TrainingLog(
        id: j['id']?.toString() ?? '',
        exerciseName: j['exerciseName']?.toString() ?? '',
        userId: j['userId']?.toString(),
        sets: j['sets'] is int ? j['sets'] as int : int.tryParse('${j['sets']}'),
        repsOrSeconds: j['repsOrSeconds']?.toString(),
        rest: j['rest']?.toString(),
        notes: j['notes']?.toString(),
        calories: j['calories'] is int ? j['calories'] as int : int.tryParse('${j['calories']}'),
        imageBase64: j['imageBase64']?.toString(),
        imageUrl: j['imageUrl']?.toString(),
        loadLevel: j['loadLevel']?.toString(),
        favoriteAtTime: j['favoriteAtTime'] == true,
        completedAt: DateTime.tryParse(j['completedAt']?.toString() ?? '') ?? DateTime.now(),
        deleted: j['deleted'] == true,
      );
}

class TrainingLogRepository {
  static const _kLogs = 'training_logs_v1';

  Future<List<TrainingLog>> fetch({bool includeDeleted = false}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kLogs);
    if (raw == null) return [];
    try {
      final dec = jsonDecode(raw);
      if (dec is! List) return [];
      final arr = dec.cast<dynamic>();
      final logs = arr
          .map((e) => TrainingLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!includeDeleted) {
        return logs.where((e) => !e.deleted).toList();
      }
      return logs;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(TrainingLog log) async {
    final sp = await SharedPreferences.getInstance();
    final logs = await fetch(includeDeleted: true);
    logs.add(log);
    await sp.setString(_kLogs, jsonEncode(logs.map((e) => e.toJson()).toList()));
  }

  Future<void> softDelete(String id) async {
    final sp = await SharedPreferences.getInstance();
    final logs = await fetch(includeDeleted: true);
    for (var i = 0; i < logs.length; i++) {
      if (logs[i].id == id) {
        logs[i] = TrainingLog(
          id: logs[i].id,
          exerciseName: logs[i].exerciseName,
          completedAt: logs[i].completedAt,
          sets: logs[i].sets,
          repsOrSeconds: logs[i].repsOrSeconds,
          rest: logs[i].rest,
          notes: logs[i].notes,
          calories: logs[i].calories,
          imageBase64: logs[i].imageBase64,
          imageUrl: logs[i].imageUrl,
          loadLevel: logs[i].loadLevel,
          favoriteAtTime: logs[i].favoriteAtTime,
          deleted: true,
        );
        break;
      }
    }
    await sp.setString(_kLogs, jsonEncode(logs.map((e) => e.toJson()).toList()));
  }
}
