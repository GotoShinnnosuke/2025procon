import 'package:flutter/material.dart';
import '../models/workout.dart';
import 'workout_detail_dialog.dart';

class WorkoutListScreen extends StatelessWidget {
  final DateTime date;
  const WorkoutListScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final workouts = [
      Workout(
        name: '筋トレ10回',
        duration: '10分',
        imageUrl: '',
        description: 'ここに詳細が入ります',
      ),
      Workout(
        name: 'ランニング5km',
        duration: '30分',
        imageUrl: '',
        description: 'ここに詳細が入ります',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text("${date.month}/${date.day} の運動一覧")),
      body: ListView.builder(
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          final workout = workouts[index];
          return Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(workout.name),
              subtitle: Text(workout.duration),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => WorkoutDetailDialog(workout: workout),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
