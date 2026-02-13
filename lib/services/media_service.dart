import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MediaResult {
  final Uint8List? bytes;
  final String? base64Data;
  final String? downloadUrl;
  final String? errorMessage;
  final int? statusCode;
  const MediaResult({this.bytes, this.base64Data, this.downloadUrl, this.errorMessage, this.statusCode});
  bool get ok => bytes != null && (bytes?.isNotEmpty ?? false);
}

class MediaService {
  final String apiKey;
  final String? baseUrl;
  final String? imageFunctionUrl;
  MediaService({required this.apiKey, this.baseUrl, this.imageFunctionUrl});

  static String _cacheKey(String name, String view, int size) =>
      'exercise_image_v1:${name.toLowerCase()}:$view:$size';

  Future<MediaResult> getExerciseImageDetailed(
    String exerciseName, {
    String view = 'front',
    int size = 512,
    bool useCache = true,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final key = _cacheKey(exerciseName, view, size);
    final storage = FirebaseStorage.instance;
    final safeName = _sanitizeName(exerciseName);
    final storageRef = storage
        .ref()
        .child('exercise-form-images/$safeName/${view}_$size.png');
    String? storageUrl;
    if (useCache) {
      final cached = sp.getString(key);
      if (cached != null && cached.isNotEmpty) {
        try {
          final bytes = base64Decode(cached);
          return MediaResult(bytes: bytes, base64Data: cached, statusCode: 200);
        } catch (_) {}
      }
      try {
        debugPrint(
            'MediaService: checking storage cache for exercise=$exerciseName view=$view size=$size');
        storageUrl = await storageRef.getDownloadURL();
        final imgRes = await http
            .get(Uri.parse(storageUrl!))
            .timeout(const Duration(seconds: 30));
        if (imgRes.statusCode == 200) {
          final bytes = imgRes.bodyBytes;
          final b64 = base64Encode(bytes);
          try {
            await sp.setString(key, b64);
          } catch (e) {
            debugPrint('MediaService: cache write failed: $e');
          }
          return MediaResult(
            bytes: bytes,
            base64Data: b64,
            downloadUrl: storageUrl,
            statusCode: 200,
          );
        }
      } catch (_) {
        storageUrl = null;
      }
    }

    if (imageFunctionUrl != null && imageFunctionUrl!.isNotEmpty) {
      return _generateImageViaFunction(
        exerciseName,
        view: view,
        size: size,
        storageRef: storageRef,
        cacheKey: key,
      );
    }

    if (apiKey.isEmpty) {
      return const MediaResult(errorMessage: '画像生成のAPIキーが未設定です（OPENAI_API_KEY）');
    }

    final uri = Uri.parse((baseUrl ?? 'https://api.openai.com') + '/v1/images/generations');
    final prompt =
        'Flat vector illustration of proper exercise form: "$exerciseName", $view view. '
        'Simple light background, gender-neutral, fully clothed, clear posture and joint angles, high contrast. '
        'No text, no watermark, non-photorealistic.';

    // Map requested size to supported values.
    // Supported: 1024x1024, 1024x1536, 1536x1024, auto
    final String sizeParam = (size <= 1024)
        ? '1024x1024'
        : '1536x1024';

    final body = {
      'model': 'gpt-image-1',
      'prompt': prompt,
      'size': sizeParam,
      // Some deployments don't accept response_format; default will be returned.
    };

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      return MediaResult(errorMessage: 'ネットワークエラー: ${e.toString()}');
    }

    if (res.statusCode != 200) {
      String? detail;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        detail = (err['error']?['message'])?.toString();
      } catch (_) {}
      // よくあるケースのガイド
      String hint = '';
      if (res.statusCode == 401) hint = '（APIキー不正/未設定）';
      if (res.statusCode == 403) hint = '（権限不足/プラン未対応の可能性）';
      if (res.statusCode == 429) hint = '（レート制限/クォータ超過）';
      if (res.statusCode == 400) {
        if ((detail?.contains('UnknownParameter') ?? false)) {
          hint = '（APIがresponse_format等のパラメータを受け付けない構成です）';
        } else if ((detail?.contains('Supported values are') ?? false)) {
          hint = '（sizeは 1024x1024 / 1024x1536 / 1536x1024 / auto のみ対応）';
        }
      }
      return MediaResult(
        statusCode: res.statusCode,
        errorMessage: '画像生成に失敗しました: HTTP ${res.statusCode} ${detail ?? ''} $hint'.trim(),
      );
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final first = (data['data'] as List).first as Map<String, dynamic>;
      Uint8List? bytes;
      String? b64 = first['b64_json'] as String?;
      if (b64 != null) {
        bytes = base64Decode(b64);
      } else if (first['url'] is String) {
        final imgUrl = first['url'] as String;
        final imgRes = await http.get(Uri.parse(imgUrl)).timeout(const Duration(seconds: 30));
        if (imgRes.statusCode == 200) {
          bytes = imgRes.bodyBytes;
          b64 = base64Encode(bytes);
        } else {
          return MediaResult(
            statusCode: imgRes.statusCode,
            errorMessage: '画像URLの取得に失敗しました: HTTP ${imgRes.statusCode}',
          );
        }
      }
      if (bytes == null) {
        return const MediaResult(errorMessage: '応答に画像データ（b64_json/url）が含まれていません');
      }
      if (b64 != null) {
        try {
          await sp.setString(key, b64);
        } catch (e) {
          debugPrint('MediaService: cache write failed: $e');
        }
      }
      try {
        await storageRef.putData(bytes, SettableMetadata(contentType: 'image/png'));
        storageUrl = await storageRef.getDownloadURL();
      } catch (_) {
        storageUrl = null;
      }
      return MediaResult(bytes: bytes, base64Data: b64, downloadUrl: storageUrl, statusCode: 200);
    } catch (e) {
      return MediaResult(errorMessage: '応答解析に失敗しました: ${e.toString()}');
    }
  }

  Future<Uint8List?> getExerciseImage(
    String exerciseName, {
    String view = 'front',
    int size = 512,
    bool useCache = true,
  }) async {
    final r = await getExerciseImageDetailed(
      exerciseName,
      view: view,
      size: size,
      useCache: useCache,
    );
    return r.bytes;
  }

  String _sanitizeName(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<MediaResult> _generateImageViaFunction(
    String exerciseName, {
    required String view,
    required int size,
    required Reference storageRef,
    required String cacheKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const MediaResult(errorMessage: 'ログインが必要です。再ログインしてください。');
    }
    final idToken = await user.getIdToken();
    final uri = Uri.parse(imageFunctionUrl!);

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'mode': 'image',
              'exerciseName': exerciseName,
              'view': view,
              'size': size,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      return MediaResult(errorMessage: 'ネットワークエラー: ${e.toString()}');
    }

    if (res.statusCode != 200) {
      String? detail;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        detail = err['error']?.toString();
      } catch (_) {}
      return MediaResult(
        statusCode: res.statusCode,
        errorMessage: '画像生成に失敗しました: HTTP ${res.statusCode} ${detail ?? ''}'.trim(),
      );
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final b64 = data['b64_json'] as String?;
      if (b64 == null || b64.isEmpty) {
        return const MediaResult(errorMessage: '応答に画像データ（b64_json）が含まれていません');
      }
      final bytes = base64Decode(b64);
      final sp = await SharedPreferences.getInstance();
      try {
        await sp.setString(cacheKey, b64);
      } catch (e) {
        debugPrint('MediaService: cache write failed: $e');
      }
      String? storageUrl;
      try {
        await storageRef.putData(bytes, SettableMetadata(contentType: 'image/png'));
        storageUrl = await storageRef.getDownloadURL();
      } catch (_) {
        storageUrl = null;
      }
      return MediaResult(
        bytes: bytes,
        base64Data: b64,
        downloadUrl: storageUrl,
        statusCode: 200,
      );
    } catch (e) {
      return MediaResult(errorMessage: '応答解析に失敗しました: ${e.toString()}');
    }
  }

  /// Returns a download URL for a stored form video if available.
  /// Upload videos to `exercise-form-videos/{exercise-name}/form.mp4`.
  Future<String?> getExerciseVideoUrl(String exerciseName) async {
    final storage = FirebaseStorage.instance;
    final safeName = _sanitizeName(exerciseName);
    final candidates = [
      'exercise-form-videos/$safeName/form.mp4',
      'exercise-form-videos/$safeName/form.webm',
      'exercise-form-videos/$safeName/form.mov',
    ];
    for (final path in candidates) {
      try {
        final ref = storage.ref().child(path);
        return await ref.getDownloadURL();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          continue;
        }
        rethrow;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

