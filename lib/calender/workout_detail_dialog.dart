import 'package:flutter/material.dart';
import '../models/workout.dart';

class WorkoutDetailDialog extends StatelessWidget {
  final Workout workout;
  const WorkoutDetailDialog({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(workout.name),
      content: SingleChildScrollView(child: Text(workout.description)),
      actions: [
        TextButton(
          child: const Text("閉じる"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
