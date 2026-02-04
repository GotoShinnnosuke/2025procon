import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'models/training_menu.dart';
import 'services/favorites.dart';
import 'services/media_service.dart';
import 'services/function_endpoints.dart';
import 'services/training_log.dart';
import 'services/training_log_firestore.dart';

/// トレーニング1種目のタイマー画面。
class TrainingTimerPage extends StatefulWidget {
  const TrainingTimerPage({super.key, required this.item, this.planId});
  final ExerciseItem item;
  final String? planId;

  @override
  State<TrainingTimerPage> createState() => _TrainingTimerPageState();
}

/// タイマー画面の状態管理と保存処理を担うState。
class _TrainingTimerPageState extends State<TrainingTimerPage> {
  late int totalSets;
  late int currentSet;
  late int setSeconds;
  int remaining = 0;
  bool running = false;
  Timer? _timer;

  late int _restSeconds;
  int _restRemaining = 0;
  bool _restRunning = false;
  Timer? _restTimer;

  Future<MediaResult>? _imageFuture;
  MediaResult? _imageResult;

  VideoPlayerController? _videoController;
  bool _videoLoading = false;
  String? _videoError;

  late final PageController _carouselController;
  Timer? _carouselTimer;
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    totalSets = widget.item.sets ?? 3;
    currentSet = 1;
    setSeconds = _parseSeconds(widget.item.repsOrSeconds) ?? 30;
    remaining = setSeconds;
    _restSeconds = _parseSeconds(widget.item.rest) ?? 0;
    _restRemaining = _restSeconds;

    _carouselController = PageController();
    _startCarouselAutoPlay();

    _imageFuture = _mediaService()
        .getExerciseImageDetailed(widget.item.name, view: 'side', size: 512);
    _imageFuture?.then((res) {
      if (!mounted) return;
      setState(() => _imageResult = res);
    });
    _loadVideoIfAvailable();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _carouselTimer?.cancel();
    _carouselController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // --- helpers -------------------------------------------------------------

  int? _parseSeconds(String? text) {
    if (text == null) return null;
    final s = text.replaceAll(' ', '');
    final minMatch = RegExp(r'(\d+)分').firstMatch(s);
    final secMatch = RegExp(r'(\d+)秒').firstMatch(s);
    final rangeMatch = RegExp(r'(\d+)\s*[-~〜]\s*(\d+)秒').firstMatch(s);
    if (rangeMatch != null) {
      final a = int.tryParse(rangeMatch.group(1)!);
      final b = int.tryParse(rangeMatch.group(2)!);
      if (a != null && b != null) return ((a + b) / 2).round();
    }
    int total = 0;
    if (minMatch != null) total += (int.tryParse(minMatch.group(1)!) ?? 0) * 60;
    if (secMatch != null) total += int.tryParse(secMatch.group(1)!) ?? 0;
    if (total > 0) return total;
    if (RegExp(r'^\d+$').hasMatch(s)) return int.parse(s);
    return null;
  }

  String _formatDurationText(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0 && s > 0) return '${m}分${s}秒';
    if (m > 0) return '${m}分';
    return '${s}秒';
  }

  double _timerDiameter(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final minSide = math.min(size.width, size.height);
    return (minSide * 0.32).clamp(140.0, 200.0);
  }

  double _carouselHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.34;
    return height.clamp(220.0, 320.0);
  }

  void _startCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_carouselController.hasClients) return;
      final next = (_carouselIndex + 1) % 2;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  // --- timers -------------------------------------------------------------

  void _start() {
    if (running) return;
    _restTimer?.cancel();
    setState(() {
      running = true;
      _restRunning = false;
      if (_restSeconds > 0) _restRemaining = _restSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining <= 1) {
        t.cancel();
        setState(() {
          running = false;
          remaining = 0;
        });
        if (_restSeconds > 0 && currentSet < totalSets) {
          _startRest(reset: true);
        }
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

  void _startRest({bool reset = false}) {
    if (_restSeconds <= 0) return;
    if (_restRunning && !reset) return;
    _restTimer?.cancel();
    setState(() {
      _restRunning = true;
      if (reset || _restRemaining <= 0) _restRemaining = _restSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restRemaining <= 1) {
        t.cancel();
        setState(() {
          _restRunning = false;
          _restRemaining = 0;
        });
      } else {
        setState(() => _restRemaining -= 1);
      }
    });
  }

  void _pauseRest() {
    _restTimer?.cancel();
    setState(() => _restRunning = false);
  }

  void _resetRest() {
    _restTimer?.cancel();
    setState(() {
      _restRunning = false;
      _restRemaining = _restSeconds;
    });
  }

  // --- media --------------------------------------------------------------

  Future<void> _loadVideoIfAvailable() async {
    final media = _mediaService();
    String? url = widget.item.videoUrl?.trim();
    url = (url != null && url.isNotEmpty)
        ? url
        : await media.getExerciseVideoUrl(widget.item.name);
    if (!mounted || url == null || url.isEmpty) return;
    setState(() {
      _videoLoading = true;
      _videoError = null;
    });
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      _videoController?.dispose();
      setState(() {
        _videoController = controller;
        _videoLoading = false;
      });
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError = 'フォーム動画を読み込めませんでした';
      });
    }
  }

  void _toggleVideoPlayback() {
    final c = _videoController;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  // --- UI parts -----------------------------------------------------------

  Widget _buildInfoSummary() {
    final targetText = widget.item.repsOrSeconds ?? '指定なし';
    final restText = widget.item.rest ??
        (_restSeconds > 0 ? _formatDurationText(_restSeconds) : '指定なし');
    final load = widget.item.loadLevel ?? '指定なし';

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildInfoChip(Icons.flag, '目標', targetText),
        _buildInfoChip(Icons.hourglass_bottom, 'クール', restText),
        _buildInfoChip(Icons.speed, '負荷', load),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToCarouselContent() {
    final steps = widget.item.steps.where((e) => e.trim().isNotEmpty).toList();
    final tips = widget.item.tips.where((e) => e.trim().isNotEmpty).toList();
    final notes = widget.item.notes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final hasHowTo = steps.isNotEmpty || tips.isNotEmpty || hasNotes;

    final visibleSteps = steps.take(2).toList();
    final extraSteps = steps.length - visibleSteps.length;
    final visibleTips = tips.take(2).toList();
    final extraTips = tips.length - visibleTips.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSummary(),
        const SizedBox(height: 8),
        if (!hasHowTo)
          const Text(
            'やり方の情報がありません',
            style: TextStyle(color: Color(0xFF6B7280)),
          )
        else ...[
          if (visibleSteps.isNotEmpty) ...[
            const Text(
              'ステップ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < visibleSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${i + 1}. ${visibleSteps[i]}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (extraSteps > 0)
              Text(
                '他${extraSteps}件',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            const SizedBox(height: 8),
          ],
          if (hasNotes) ...[
            const Text(
              'メモ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              notes!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (visibleTips.isNotEmpty) ...[
            const Text(
              'コツ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final tip in visibleTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('・',
                        style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tip,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (extraTips > 0)
              Text(
                '他${extraTips}件',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildRestTimerCard() {
    if (_restSeconds <= 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'クールタイムタイマー',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(height: 12),
            _TimerCircle(
              seconds: _restRemaining,
              total: _restSeconds,
              diameter: 140,
              progressColor: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFFDCEBFF),
              textColor: const Color(0xFF1D4ED8),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_restRunning)
                  FilledButton.icon(
                    onPressed: () => _startRest(reset: true),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('クールタイム開始'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _pauseRest,
                    icon: const Icon(Icons.pause),
                    label: const Text('一時停止'),
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _resetRest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('リセット'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return FutureBuilder<MediaResult>(
      future: _imageFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('フォーム画像を生成中です'),
              ],
            ),
          );
        }
        final result = snap.data ?? _imageResult;
        final bytes = result?.bytes;
        if (bytes == null || bytes.isEmpty) {
          return Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _imageFuture =
                      _mediaService().getExerciseImageDetailed(
                    widget.item.name,
                    view: 'side',
                    size: 512,
                    useCache: false,
                  );
                });
              },
              child: Text(result?.errorMessage ?? 'フォーム画像の取得に失敗しました'),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, height: 160, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  MediaService _mediaService() {
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    return MediaService(
      apiKey: key,
      imageFunctionUrl: kGenerateMenuFunctionUrl,
    );
  }

  Widget _buildCarouselCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildCarouselIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == _carouselIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6C63FF) : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildTopCarousel() {
    return Column(
      children: [
        SizedBox(
          height: _carouselHeight(context),
          child: PageView(
            controller: _carouselController,
            onPageChanged: (index) => setState(() => _carouselIndex = index),
            children: [
              _buildCarouselCard(
                title: 'やり方・目標',
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 4),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _buildHowToCarouselContent(),
                    ),
                  ),
                ),
              ),
              _buildCarouselCard(
                title: 'フォーム画像',
                child: Center(child: _buildMediaSection()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildCarouselIndicator(2),
      ],
    );
  }

  Widget _buildTimerCard(bool finished) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 520;
        final isRestPhase = _restSeconds > 0 &&
            (_restRunning ||
                (remaining == 0 &&
                    _restRemaining > 0 &&
                    currentSet < totalSets));
        final canAdvanceSet = remaining == 0 &&
            currentSet < totalSets &&
            !isRestPhase &&
            _restRemaining == 0;
        final activeSeconds = isRestPhase ? _restRemaining : remaining;
        final activeTotal = isRestPhase ? _restSeconds : setSeconds;
        final progressColor =
            isRestPhase ? const Color(0xFF3B82F6) : const Color(0xFFF97316);
        final backgroundColor =
            isRestPhase ? const Color(0xFFDCEBFF) : const Color(0xFFFFE5D0);
        final textColor =
            isRestPhase ? const Color(0xFF1D4ED8) : const Color(0xFF9A3412);

        final actions = Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (!finished) ...[
              if (isRestPhase) ...[
                if (_restRunning)
                  FilledButton.icon(
                    onPressed: _pauseRest,
                    icon: const Icon(Icons.pause),
                    label: const Text('クールタイム停止'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _startRest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('クールタイム再開'),
                  ),
                OutlinedButton.icon(
                  onPressed: _resetRest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('リセット'),
                ),
              ] else if (canAdvanceSet) ...[
                FilledButton.icon(
                  onPressed: _nextSet,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('次のセットへ'),
                ),
              ] else ...[
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
                OutlinedButton.icon(
                  onPressed: _resetSet,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('リセット'),
                ),
              ],
              TextButton.icon(
                onPressed: () {
                  _timer?.cancel();
                  Navigator.of(context).pop(false);
                },
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Color(0xFFB91C1C)),
                label: const Text('途中終了',
                    style: TextStyle(color: Color(0xFFB91C1C))),
              ),
            ] else
              FilledButton.icon(
                onPressed: _saveLog,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('記録して完了'),
              ),
          ],
        );

        final infoColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'セット $currentSet / $totalSets',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isRestPhase)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'クールタイム中',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            actions,
          ],
        );

        final timer = _TimerCircle(
          seconds: activeSeconds,
          total: activeTotal,
          diameter: _timerDiameter(context),
          progressColor: progressColor,
          backgroundColor: backgroundColor,
          textColor: textColor,
        );

        final content = isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(child: timer),
                  const SizedBox(height: 12),
                  infoColumn,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: timer,
                  ),
                  Expanded(child: infoColumn),
                ],
              );

        return Card(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildMediaSection() {
    final controller = _videoController;
    if (_videoLoading) return const _VideoLoadingCard();
    if (controller != null && controller.value.isInitialized) {
      return _VideoPlayerCard(
          controller: controller, onTogglePlay: _toggleVideoPlayback);
    }
    if (_videoError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VideoErrorBanner(
              message: _videoError!, onRetry: _loadVideoIfAvailable),
          const SizedBox(height: 12),
          _buildImageSection(),
        ],
      );
    }
    return _buildImageSection();
  }

  // --- save ---------------------------------------------------------------

  Future<String?> _uploadImageToStorage(
      Uint8List bytes, String uid, String logId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('training-log-images/$uid/$logId.png');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  Future<void> _saveLog() async {
    debugPrint('TrainingTimer: save button tapped');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('記録にはログインが必要です。ログイン後にもう一度お試しください')),
      );
      return;
    }
    final fav = await FavoritesRepository().isFavorite(widget.item);
    const int firestoreSoftLimit = 900000;
    final imageData = _imageResult?.base64Data;
    final bool imageTooLarge = (imageData?.length ?? 0) > firestoreSoftLimit;
    final baseBytes = _imageResult?.bytes;
    String? imageUrl = _imageResult?.downloadUrl;

    final logId =
        'log_${DateTime.now().millisecondsSinceEpoch}_${widget.item.name}';
    if (baseBytes != null && imageUrl == null) {
      final uploaded = await _uploadImageToStorage(baseBytes, uid, logId);
      imageUrl = uploaded ?? imageUrl;
    }

    final log = TrainingLog.fromExercise(
      widget.item,
      favorite: fav,
      userId: uid,
      id: logId,
      imageBase64: imageTooLarge ? null : imageData,
      imageUrl: imageUrl,
      planId: widget.planId,
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
      const SnackBar(content: Text('修正を反映しました')),
    );

    final messages = <String>[
      saved
          ? '記録を保存しました'
          : 'クラウド保存に失敗しました: ${errorMessage ?? ''}。ローカルに記録しました',
    ];
    if (imageTooLarge) {
      messages.add('フォーム画像が大きすぎたためBase64保存を省略しました');
    }
    if (imageUrl == null && baseBytes != null) {
      messages.add('フォーム画像をクラウドに保存できませんでした');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messages.join('\n'))),
    );
    Navigator.of(context).pop(true);
  }

  // --- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final finished = currentSet >= totalSets && remaining == 0 && !running;
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (currentUser == null) const _LoginStatusBanner(),
              _buildTopCarousel(),
              const SizedBox(height: 12),
              _buildTimerCard(finished),
            ],
          ),
        ),
      ),
    );
  }
}

// --- widgets --------------------------------------------------------------

/// 残り時間を円形プログレスで表示するウィジェット。
class _TimerCircle extends StatelessWidget {
  const _TimerCircle({
    required this.seconds,
    required this.total,
    this.diameter = 220,
    this.progressColor,
    this.backgroundColor,
    this.textColor,
  });
  final int seconds;
  final int total;
  final double diameter;
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? seconds / total : 0.0;
    final progress = progressColor ?? Theme.of(context).colorScheme.primary;
    final background = backgroundColor ?? const Color(0xFFE5E7EB);
    final labelColor = textColor ?? const Color(0xFF111827);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: diameter,
          height: diameter,
          child: CircularProgressIndicator(
            value: fraction,
            strokeWidth: 14,
            backgroundColor: background,
            valueColor: AlwaysStoppedAnimation<Color>(progress),
          ),
        ),
        Text(
          _format(seconds),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: labelColor,
          ),
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

/// フォーム動画を再生するカード。
class _VideoPlayerCard extends StatelessWidget {
  const _VideoPlayerCard({required this.controller, required this.onTogglePlay});
  final VideoPlayerController controller;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final aspect = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: VideoPlayer(controller),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.7),
                child: IconButton(
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: onTogglePlay,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.only(top: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// フォーム動画の読み込み中表示。
class _VideoLoadingCard extends StatelessWidget {
  const _VideoLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text('フォーム動画を読み込み中です'),
        ],
      ),
    );
  }
}

/// フォーム動画の読み込みエラー時バナー。
class _VideoErrorBanner extends StatelessWidget {
  const _VideoErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

/// 未ログイン時の注意バナー。
class _LoginStatusBanner extends StatelessWidget {
  const _LoginStatusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Color(0xFF92400E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '現在ログインしていません。記録を保存するにはログインが必要です。',
              style: TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}
