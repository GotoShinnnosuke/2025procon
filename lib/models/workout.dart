import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  final String id;
  final String name;
  final DateTime date;
  final int duration;
  final int calories;

  Workout({
    required this.id,
    required this.name,
    required this.date,
    required this.duration,
    required this.calories,
  });

  // Firestore → Workout
  factory Workout.fromFirestore(Map<String, dynamic> data, String id) {
    return Workout(
      id: id,
      name: data['name'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      duration: (data['duration'] ?? 0) as int,
      calories: (data['calories'] ?? 0) as int,
    );
  }

  // Workout → Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'date': Timestamp.fromDate(date),
      'duration': duration,
      'calories': calories,
    };
  }
}
