import 'dart:async';
import 'package:flutter/material.dart';
import 'models/training_menu.dart';
import 'services/favorites.dart';
import 'services/training_log.dart';
import 'services/training_log_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainingTimerPage extends StatefulWidget {
  const TrainingTimerPage({super.key, required this.item});
  final ExerciseItem item;

  @override
  State<TrainingTimerPage> createState() => _TrainingTimerPageState();
}

class _TrainingTimerPageState extends State<TrainingTimerPage> {
  late int totalSets;
  late int currentSet; // 1-based
  late int setSeconds;
  Timer? _timer;
  int remaining = 0;
  bool running = false;

  @override
  void initState() {
    super.initState();
    totalSets = widget.item.sets ?? 3;
    currentSet = 1;
    setSeconds = _parseSeconds(widget.item.repsOrSeconds) ?? 30;
    remaining = setSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (running) return;
    setState(() => running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining <= 1) {
        t.cancel();
        setState(() {
          running = false;
          remaining = 0;
        });
      } else {
        setState(() => remaining -= 1);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => running = false);
  }

  void _resetSet() {
    _timer?.cancel();
    setState(() {
      running = false;
      remaining = setSeconds;
    });
  }

  void _nextSet() {
    if (currentSet < totalSets) {
      setState(() {
        currentSet += 1;
        remaining = setSeconds;
        running = false;
      });
    }
  }

  int? _parseSeconds(String? text) {
    if (text == null) return null;
    final s = text.replaceAll(' ', '');
    // 例: 30秒, 1分, 1分30秒, 20-30秒
    final minMatch = RegExp(r"(\d+)分").firstMatch(s);
    final secMatch = RegExp(r"(\d+)秒").firstMatch(s);
    final rangeMatch = RegExp(r"(\d+)\s*[-〜~]\s*(\d+)秒").firstMatch(s);
    if (rangeMatch != null) {
      final a = int.tryParse(rangeMatch.group(1)!);
      // 平均か高い方を採用。ここでは中庸として平均。
      final b = int.tryParse(rangeMatch.group(2)!);
      if (a != null && b != null) return ((a + b) / 2).round();
    }
    int total = 0;
    if (minMatch != null) {
      total += (int.tryParse(minMatch.group(1) ?? '') ?? 0) * 60;
    }
    if (secMatch != null) {
      total += int.tryParse(secMatch.group(1) ?? '') ?? 0;
    }
    if (total > 0) return total;
    // fallback: 数字のみなら秒として扱う
    final justNum = RegExp(r"^\d+$");
    if (justNum.hasMatch(s)) return int.parse(s);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final finished = currentSet >= totalSets && remaining == 0 && !running;
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングタイマー'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.item.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'セット ${currentSet} / ${totalSets}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: _TimerCircle(seconds: remaining, total: setSeconds),
                ),
              ),
              if (!finished) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!running)
                      FilledButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('計測開始'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _pause,
                        icon: const Icon(Icons.pause),
                        label: const Text('一時停止'),
                      ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _resetSet,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('リセット'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFB91C1C)),
                  label: const Text('途中終了', style: TextStyle(color: Color(0xFFB91C1C))),
                ),
                const SizedBox(height: 12),
                if (remaining == 0 && currentSet < totalSets)
                  FilledButton.icon(
                    onPressed: _nextSet,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('次のセットへ'),
                  ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () async {
                    final fav = await FavoritesRepository().isFavorite(widget.item);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final log = TrainingLog.fromExercise(widget.item, favorite: fav, userId: uid);
                    bool saved = false;
                    try {
                      // Firestoreへ保存
                      await TrainingLogFirestoreRepository().add(log);
                      saved = true;
                    } catch (_) {
                      // Firestore保存に失敗した場合はローカルへフォールバック
                    }
                    if (!saved) {
                      await TrainingLogRepository().add(log);
                    }
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('記録して完了'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerCircle extends StatelessWidget {
  const _TimerCircle({required this.seconds, required this.total});
  final int seconds;
  final int total;
  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? seconds / total : 0.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: CircularProgressIndicator(
            value: fraction,
            strokeWidth: 14,
            backgroundColor: const Color(0xFFE5E7EB),
          ),
        ),
        Text(
          _format(seconds),
          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _format(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }
}
