import 'package:flutter/material.dart';

import '../models/training_log_entry.dart';
import 'workout_detail_dialog.dart';

class WorkoutListScreen extends StatelessWidget {
  final DateTime date;
  final List<TrainingLogEntry> workouts;

  const WorkoutListScreen({
    super.key,
    required this.date,
    this.workouts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final filtered = workouts
        .where((w) =>
            w.completedAt.year == date.year &&
            w.completedAt.month == date.month &&
            w.completedAt.day == date.day)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text("${date.month}/${date.day} の運動一覧")),
      body: filtered.isEmpty
          ? const Center(child: Text('この日に運動は登録されていません。'))
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final workout = filtered[index];
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(workout.exerciseName),
                    subtitle: Text(
                      'セット: ${workout.sets ?? '-'} | カロリー: ${workout.calories ?? '-'}kcal',
                    ),
                    onTap: () => showWorkoutDetailDialog(context, workout),
                  ),
                );
              },
            ),
    );
  }
}
