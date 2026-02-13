import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/training_log_entry.dart';

void showWorkoutDetailDialog(BuildContext context, TrainingLogEntry log) {
  showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          bool showImage = false;
          final imageWidget = _buildImageWidget(log);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text('${log.exerciseName}の詳細')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: imageWidget == null
                        ? null
                        : () {
                            setState(() {
                              showImage = true;
                            });
                          },
                    icon: const Icon(Icons.image),
                    label: const Text('フォームを確認'),
                  ),
                ),
                const SizedBox(height: 8),
                if (showImage && imageWidget != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageWidget,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${log.completedAt.year}年${log.completedAt.month}月${log.completedAt.day}日 '
                      '${log.completedAt.hour.toString().padLeft(2, '0')}:${log.completedAt.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.repeat, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Text('セット: ${log.sets ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Text('回数/秒数: ${log.repsOrSeconds ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Text('負荷: ${log.loadLevel ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 12),
                if (log.calories != null)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('消費カロリー: ${log.calories}kcal'),
                    ],
                  ),
                if ((log.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('メモ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(log.notes!),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget? _buildImageWidget(TrainingLogEntry log) {
  if (log.imageUrl != null && log.imageUrl!.isNotEmpty) {
    return Image.network(log.imageUrl!);
  }
  if (log.imageBase64 != null && log.imageBase64!.isNotEmpty) {
    return Image.memory(base64Decode(log.imageBase64!));
  }
  return null;
}
