import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only view model that mirrors documents stored in the `trainingLogs`
/// collection. It keeps nullable fields flexible so that Firestore documents
/// missing optional data do not break the calendar UI.
class TrainingLogEntry {
  final String id;
  final String exerciseName;
  final DateTime completedAt;
  final bool deleted;
  final String? userId;
  final int? calories;
  final int? sets;
  final String? repsOrSeconds;
  final String? rest;
  final String? notes;
  final String? imageBase64;
  final String? imageUrl;
  final bool favoriteAtTime;

  const TrainingLogEntry({
    required this.id,
    required this.exerciseName,
    required this.completedAt,
    required this.deleted,
    required this.favoriteAtTime,
    this.userId,
    this.calories,
    this.sets,
    this.repsOrSeconds,
    this.rest,
    this.notes,
    this.imageBase64,
    this.imageUrl,
  });

  factory TrainingLogEntry.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    DateTime completedAt = DateTime.now();
    final completedRaw = data['completedAt'];
    if (completedRaw is Timestamp) {
      completedAt = completedRaw.toDate();
    } else if (completedRaw is DateTime) {
      completedAt = completedRaw;
    } else if (completedRaw is String) {
      completedAt = DateTime.tryParse(completedRaw) ?? DateTime.now();
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
      deleted: data['deleted'] == true,
      favoriteAtTime: data['favoriteAtTime'] == true,
      userId: data['userId']?.toString(),
      calories: parseInt(data['calories']),
      sets: parseInt(data['sets']),
      repsOrSeconds: data['repsOrSeconds']?.toString(),
      rest: data['rest']?.toString(),
      notes: data['notes']?.toString(),
      imageBase64: data['imageBase64']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
    );
  }
}
