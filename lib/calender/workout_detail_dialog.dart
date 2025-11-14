import 'package:flutter/material.dart';
import '../models/training_log_entry.dart';

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final twoDigits = (int value) => value.toString().padLeft(2, '0');
  return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

void showWorkoutDetailDialog(
    BuildContext context, TrainingLogEntry workout) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(workout.exerciseName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日付: ${_formatDate(workout.completedAt)}'),
          if (workout.sets != null) Text('セット数: ${workout.sets}'),
          if ((workout.repsOrSeconds ?? '').isNotEmpty)
            Text('回数/秒数: ${workout.repsOrSeconds}'),
          if ((workout.rest ?? '').isNotEmpty)
            Text('休憩: ${workout.rest}'),
          if (workout.calories != null)
            Text('カロリー: ${workout.calories}kcal'),
          if ((workout.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'メモ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(workout.notes!),
          ],
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
