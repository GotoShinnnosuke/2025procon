import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'models/training_menu.dart';
import 'services/favorites.dart';
import 'services/training_log.dart';
import 'services/training_log_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/media_service.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

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
  Future<MediaResult>? _imageFuture;
  MediaResult? _imageResult;
  VideoPlayerController? _videoController;
  bool _videoLoading = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    totalSets = widget.item.sets ?? 3;
    currentSet = 1;
    setSeconds = _parseSeconds(widget.item.repsOrSeconds) ?? 30;
    remaining = setSeconds;
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    _imageFuture = MediaService(apiKey: key)
        .getExerciseImageDetailed(widget.item.name, view: 'side', size: 512);
    _imageFuture!.then((res) {
      if (!mounted) return;
      setState(() => _imageResult = res);
    });
    _loadVideoIfAvailable();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
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

  Future<String?> _uploadImageToStorage(Uint8List bytes, String uid, String logId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('training-log-images/$uid/$logId.png');
      debugPrint('TrainingTimer: uploading image to path ${ref.fullPath}');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  Future<void> _loadVideoIfAvailable() async {
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    final media = MediaService(apiKey: key);
    String? url = widget.item.videoUrl?.trim();
    url = (url != null && url.isNotEmpty) ? url : await media.getExerciseVideoUrl(widget.item.name);
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
    } catch (e) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError = 'フォーム動画を読み込めませんでした';
      });
    }
  }

  void _toggleVideoPlayback() {
    final controller = _videoController;
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
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
                final key = const String.fromEnvironment('OPENAI_API_KEY');
                setState(() {
                  _imageFuture = MediaService(apiKey: key).getExerciseImageDetailed(
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

  Widget _buildMediaSection() {
    final controller = _videoController;
    if (_videoLoading) {
      return const _VideoLoadingCard();
    }
    if (controller != null && controller.value.isInitialized) {
      return _VideoPlayerCard(
        controller: controller,
        onTogglePlay: _toggleVideoPlayback,
      );
    }
    if (_videoError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VideoErrorBanner(
            message: _videoError!,
            onRetry: _loadVideoIfAvailable,
          ),
          const SizedBox(height: 12),
          _buildImageSection(),
        ],
      );
    }
    return _buildImageSection();
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
    final currentUser = FirebaseAuth.instance.currentUser;
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
              if (currentUser == null)
                const _LoginStatusBanner(),
              _buildMediaSection(),
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
                    debugPrint('TrainingTimer: save button tapped');
                    final fav = await FavoritesRepository().isFavorite(widget.item);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    debugPrint('TrainingTimerPage save uid=$uid');
                    if (uid == null) {
                      debugPrint('TrainingTimer: user not logged in, abort');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('記録にはログインが必要です。ログイン後にもう一度お試しください。')),
                      );
                      return;
                    }
                    const int firestoreSoftLimit = 900000; // bytes (chars) safety margin
                    final imageData = _imageResult?.base64Data;
                    final bool imageTooLarge = (imageData?.length ?? 0) > firestoreSoftLimit;
                    final baseBytes = _imageResult?.bytes;
                    String? imageUrl = _imageResult?.downloadUrl;
                    debugPrint(
                        'TrainingTimer: imageResult bytes=${baseBytes?.length ?? 0}, hasDownloadUrl=${imageUrl != null}');

                    final logId = 'log_${DateTime.now().millisecondsSinceEpoch}_${widget.item.name}';
                    if (baseBytes != null) {
                      if (imageTooLarge) {
                        debugPrint('TrainingTimer: image too large for Base64 storage, will upload only');
                      }
                      if (imageUrl == null) {
                        debugPrint('TrainingTimer: attempting to upload image to Storage');
                        final uploaded = await _uploadImageToStorage(baseBytes, uid, logId);
                        imageUrl = uploaded ?? imageUrl;
                      }
                    }

                    final log = TrainingLog.fromExercise(
                      widget.item,
                      favorite: fav,
                      userId: uid,
                      id: logId,
                      imageBase64: imageTooLarge ? null : imageData,
                      imageUrl: imageUrl,
                    );
                    bool saved = false;
                    String? errorMessage;
                    try {
                      // Firestoreへ保存
                      debugPrint('TrainingTimer: writing log to Firestore for id=$logId');
                      await TrainingLogFirestoreRepository().add(log);
                      debugPrint('TrainingTimer: Firestore write succeeded');
                      saved = true;
                    } catch (e) {
                      debugPrint('TrainingTimer: Firestore write failed: $e');
                      errorMessage = e.toString();
                      // Firestore保存に失敗した場合はローカルへフォールバック
                    }
                    if (!saved) {
                      debugPrint('TrainingTimer: saving to local repository instead');
                      await TrainingLogRepository().add(log);
                    }
                    if (!mounted) return;
                    final messages = <String>[
                      saved
                          ? '記録を保存しました'
                          : 'クラウド保存に失敗しました（${errorMessage ?? 'オフラインモード'}）。ローカルに記録しました',
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

class _VideoPlayerCard extends StatelessWidget {
  const _VideoPlayerCard({
    required this.controller,
    required this.onTogglePlay,
  });

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
