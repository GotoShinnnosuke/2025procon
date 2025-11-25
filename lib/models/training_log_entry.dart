import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/training_menu.dart';

class TrainingLogEntry {
  final String id;
  final String exerciseName;
  final DateTime completedAt;
  final int? sets;
  final String? repsOrSeconds;
  final int? calories;
  final String? rest;
  final String? notes;
  final String? imageUrl;
  final String? imageBase64;
  final String? loadLevel;

  const TrainingLogEntry({
    required this.id,
    required this.exerciseName,
    required this.completedAt,
    this.sets,
    this.repsOrSeconds,
    this.calories,
    this.rest,
    this.notes,
    this.imageUrl,
    this.imageBase64,
    this.loadLevel,
  });

  factory TrainingLogEntry.fromFirestore(
      Map<String, dynamic> data, String id) {
    DateTime completedAt = DateTime.now();
    final rawCompleted = data['completedAt'];
    if (rawCompleted is Timestamp) {
      completedAt = rawCompleted.toDate();
    } else if (rawCompleted is DateTime) {
      completedAt = rawCompleted;
    } else if (rawCompleted is String) {
      completedAt = DateTime.tryParse(rawCompleted) ?? DateTime.now();
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return TrainingLogEntry(
      id: id,
      exerciseName: (data['exerciseName'] ?? '').toString(),
      completedAt: completedAt,
      sets: parseInt(data['sets']),
      repsOrSeconds: data['repsOrSeconds']?.toString(),
      calories: parseInt(data['calories']),
      rest: data['rest']?.toString(),
      notes: data['notes']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      imageBase64: data['imageBase64']?.toString(),
      loadLevel: data['loadLevel']?.toString(),
    );
  }

  ExerciseItem toExerciseItem() {
    return ExerciseItem(
      name: exerciseName,
      sets: sets,
      repsOrSeconds: repsOrSeconds,
      rest: rest,
      notes: notes,
      calories: calories,
      imageUrl: imageUrl,
      loadLevel: loadLevel,
    );
  }
}
