import 'package:flutter/material.dart';
import '../models/workout.dart';

/// 運動詳細をポップアップで表示する関数
void showWorkoutDetailDialog(BuildContext context, Workout workout) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.fitness_center, color: Color.fromARGB(255, 224, 142, 202)),
            const SizedBox(width: 8),
            Text('${workout.name} の詳細'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (workout.date != null)
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color.fromARGB(255, 143, 249, 225),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${workout.date!.year}年${workout.date!.month}月${workout.date!.day}日',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer, color: Color.fromARGB(255, 233, 91, 91), size: 20),
                const SizedBox(width: 8),
                Text(
                  workout.duration != null
                      ? '運動時間：${workout.duration}分'
                      : '運動時間：${workout.durationLabel ?? '-'}',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (workout.calories != null)
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Color.fromARGB(255, 181, 248, 214),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '消費カロリー：${workout.calories} kcal',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '閉じる',
              style: TextStyle(color: Color.fromARGB(255, 170, 141, 219)),
            ),
          ),
        ],
      );
    },
  );
}
