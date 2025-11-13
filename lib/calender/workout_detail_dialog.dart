import 'package:flutter/material.dart';
import '../models/workout.dart';

void showWorkoutDetailDialog(BuildContext context, Workout workout) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(workout.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日付: ${workout.date.toLocal()}'),
          Text('時間: ${workout.duration}分'),
          Text('カロリー: ${workout.calories}kcal'),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('閉じる'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
