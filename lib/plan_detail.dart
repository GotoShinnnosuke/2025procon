import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/training_menu.dart';
import 'services/favorites.dart';
import 'services/media_service.dart';
import 'services/function_endpoints.dart';
import 'services/training_log.dart';
import 'services/training_log_firestore.dart';
import 'training_timer.dart';

/// トレーニングプランの詳細確認と実行を行う画面。
class PlanDetailPage extends StatefulWidget {
  const PlanDetailPage({super.key, required this.plan, this.minutes});
  final TrainingMenu plan;
  final int? minutes;

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  bool _running = false;
  bool _isFavorite = false;
  late final MediaService _media;
  final Map<String, Future<MediaResult>> _imageFutures = {};
  Future<void> _imageQueue = Future.value();

  @override
  void initState() {
    super.initState();
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    _media =
        MediaService(apiKey: key, imageFunctionUrl: kGenerateMenuFunctionUrl);
    _loadFavorite();
  }

  Future<MediaResult> _enqueueExerciseImage(ExerciseItem exercise) {
    return _imageFutures.putIfAbsent(exercise.name, () {
      final future = _imageQueue.then(
        (_) => _media.getExerciseImageDetailed(
          exercise.name,
          view: 'side',
          size: 512,
        ),
      );
      _imageQueue = future.then((_) {}).catchError((_) {});
      return future;
    });
  }

  Future<void> _loadFavorite() async {
    final fav = await PlanFavoritesRepository().isFavorite(widget.plan);
    if (!mounted) return;
    setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    try {
      final now = await PlanFavoritesRepository()
          .toggle(widget.plan, minutes: widget.minutes);
      if (!mounted) return;
      setState(() => _isFavorite = now);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(now ? 'お気に入りに追加しました' : 'お気に入りを解除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _savePlanLog(String planId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録にはログインが必要です。')),
      );
      return;
    }
    final log = TrainingLog.fromPlan(
      widget.plan,
      minutes: widget.minutes,
      userId: uid,
      id: planId,
    );
    bool saved = false;
    String? errorMessage;
    try {
      await TrainingLogFirestoreRepository().add(log);
      saved = true;
    } catch (e) {
      errorMessage = e.toString();
    }
    if (!saved) {
      await TrainingLogRepository().add(log);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'プランを記録しました'
            : 'クラウド保存に失敗しました: ${errorMessage ?? ''}。ローカルに記録しました'),
      ),
    );
  }

  Future<void> _runSingle(ExerciseItem item) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TrainingTimerPage(item: item)),
    );
  }

  Future<bool> _confirmNext(String nextName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('次の種目へ進みますか？'),
        content: Text('次は「$nextName」を実行します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('終了'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _runPlan({int startIndex = 0}) async {
    if (_running) return;
    final exercises = widget.plan.exercises;
    if (exercises.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プランに種目がありません。')),
      );
      return;
    }
    setState(() => _running = true);
    var completedAll = true;
    final planRunId =
        'plan_${DateTime.now().millisecondsSinceEpoch}_${widget.plan.name}';
    for (int i = startIndex; i < exercises.length; i++) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TrainingTimerPage(item: exercises[i], planId: planRunId),
        ),
      );
      if (!mounted) return;
      if (result != true) {
        completedAll = false;
        break;
      }
      if (i < exercises.length - 1) {
        final ok = await _confirmNext(exercises[i + 1].name);
        if (!ok) {
          completedAll = false;
          break;
        }
      }
    }
    if (mounted) setState(() => _running = false);
    if (completedAll) {
      await _savePlanLog(planRunId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final minutes = widget.minutes;
    final summary = plan.summary ?? '';
    final intensity = plan.intensity ?? '指定なし';
    final caution = plan.caution ?? '';
    final exercises = plan.exercises;

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングメニュー'),
        leadingWidth: 120,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('前の画面へ'),
        ),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(summary),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (minutes != null)
                            _InfoChip(label: '目安: ${minutes}分'),
                          _InfoChip(label: '負荷: $intensity'),
                          _InfoChip(label: '種目数: ${exercises.length}'),
                        ],
                      ),
                      if (caution.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '注意: $caution',
                          style: const TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _running ? null : () => _runPlan(),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_running ? '実行中...' : 'このプランを実行'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '種目一覧',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2A37),
                    ),
              ),
              const SizedBox(height: 8),
              for (final ex in exercises)
                _ExerciseCard(
                  exercise: ex,
                  onRun: () => _runSingle(ex),
                  imageFuture: _enqueueExerciseImage(ex),
                ),
              if (exercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '種目が登録されていません。',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onRun,
    this.imageFuture,
  });
  final ExerciseItem exercise;
  final VoidCallback onRun;
  final Future<MediaResult>? imageFuture;

  @override
  Widget build(BuildContext context) {
    final notes = exercise.notes?.trim() ?? '';
    final tips = exercise.tips;
    final steps = exercise.steps;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageFuture != null) ...[
              _ExerciseImagePreview(future: imageFuture!),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('実行'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(label: 'セット: ${exercise.sets ?? '-'}'),
                _InfoChip(label: '回数/秒数: ${exercise.repsOrSeconds ?? '-'}'),
                _InfoChip(label: '休憩: ${exercise.rest ?? '-'}'),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'メモ: $notes',
                style: const TextStyle(color: Color(0xFF4B5563)),
              ),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'ステップ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final step in steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('・$step'),
                ),
            ],
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'コツ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final tip in tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('・$tip'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseImagePreview extends StatelessWidget {
  const _ExerciseImagePreview({required this.future});
  final Future<MediaResult> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaResult>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _imageContainer(
            child: const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError) {
          return _imageContainer(
            child: _errorText('画像取得に失敗しました: ${snap.error}'),
          );
        }
        final result = snap.data;
        final bytes = result?.bytes;
        if (bytes == null || bytes.isEmpty) {
          final message = result?.errorMessage ??
              (result?.statusCode != null
                  ? '画像取得に失敗しました (HTTP ${result?.statusCode})'
                  : '画像取得に失敗しました');
          return _imageContainer(
            child: _errorText(message),
          );
        }
        return _imageContainer(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  Widget _errorText(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _imageContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        width: double.infinity,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
