import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/training_menu.dart';

abstract class AIServiceBase {
  Future<List<TrainingMenu>> generatePlans(String userInput);
  Future<List<ExerciseItem>> generateExercises(String userInput);
}

class AIServiceException implements Exception {
  final String message;
  final int? statusCode;
  final String? detail;
  AIServiceException(this.message, {this.statusCode, this.detail});
  @override
  String toString() => statusCode == null
      ? message
      : '$message (HTTP $statusCode${detail != null ? ': $detail' : ''})';
}

class OpenAIAIService implements AIServiceBase {
  final String apiKey;
  final String? baseUrl; // Optional override for proxy/backend
  final String? menuFunctionUrl;

  OpenAIAIService({
    required this.apiKey,
    this.baseUrl,
    this.menuFunctionUrl,
  });

  @override
  Future<List<TrainingMenu>> generatePlans(String userInput) async {
    if (menuFunctionUrl != null && menuFunctionUrl!.isNotEmpty) {
      return _generatePlansViaFunction(userInput);
    }
    if (apiKey.isEmpty) {
      throw AIServiceException(
        'APIキーが未設定です。--dart-define=OPENAI_API_KEY=... を指定してください。',
      );
    }

    final uri = Uri.parse((baseUrl ?? 'https://api.openai.com') +
        '/v1/chat/completions');
    final body = {
      'model': 'gpt-4o-mini',
      'temperature': 0.7,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'あなたは日本語のパーソナルトレーナー。JSONのみを返す。'
              '形式: {"plans":[{name,durationWeeks,daysPerWeek,intensity,summary,exercises:[{name,sets,repsOrSeconds,rest,notes,tips:[string],steps:[string]}],caution}] }'
              'steps/tips/notesには足・手の置き方、動作方向、姿勢、呼吸、よくあるNGを具体的に。'
              '3案だけ返す。',
        },
        {
          'role': 'user',
          'content': userInput,
        },
      ],
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
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw AIServiceException('タイムアウトしました。通信環境を確認して再試行してください。');
    } catch (e) {
      throw AIServiceException(
        'ネットワークエラーが発生しました。接続を確認してください。',
        detail: e.toString(),
      );
    }

    if (res.statusCode != 200) {
      String? apiDetail;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        final errObj = err['error'] as Map<String, dynamic>?;
        apiDetail = errObj?['message']?.toString();
      } catch (_) {}

      final msg = _mapStatusToMessage(res.statusCode, apiDetail);
      throw AIServiceException(msg, statusCode: res.statusCode, detail: apiDetail);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?);
    if (choices == null || choices.isEmpty) {
      throw AIServiceException('モデルからの応答が取得できませんでした。しばらくして再試行してください。');
    }
    final content = choices.first['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw AIServiceException('応答が空でした。条件を短く/具体的にして再試行してください。');
    }
    Map<String, dynamic> jsonObj;
    try {
      jsonObj = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw AIServiceException('応答の解析に失敗しました。もう一度お試しください。',
          detail: e.toString());
    }
    final List plans = (jsonObj['plans'] as List?) ?? const [];
    return plans
        .take(3)
        .map((e) => TrainingMenu.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<ExerciseItem>> generateExercises(String userInput) async {
    if (apiKey.isEmpty) {
      throw AIServiceException(
        'APIキーが未設定です。--dart-define=OPENAI_API_KEY=... を指定してください。',
      );
    }

    final uri = Uri.parse((baseUrl ?? 'https://api.openai.com') +
        '/v1/chat/completions');
    final body = {
      'model': 'gpt-4o-mini',
      'temperature': 0.7,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'あなたは日本語のパーソナルトレーナー。JSONのみを返す。'
              '形式: {"exercises":[{name,sets,repsOrSeconds,rest,notes,calories,tips:[string],steps:[string]}] }'
              'steps/tips/notesには足・手の置き方、動作方向、姿勢、呼吸、よくあるNGを具体的に。'
              '10種目まで。',
        },
        {
          'role': 'user',
          'content': userInput,
        },
      ],
    };

    final res = await _safePost(uri, body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?);
    if (choices == null || choices.isEmpty) {
      throw AIServiceException('モデルからの応答が取得できませんでした。しばらくして再試行してください。');
    }
    final content = choices.first['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw AIServiceException('応答が空でした。条件を短く/具体的にして再試行してください。');
    }
    Map<String, dynamic> jsonObj;
    try {
      jsonObj = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw AIServiceException('応答の解析に失敗しました。もう一度お試しください。',
          detail: e.toString());
    }
    final List list = (jsonObj['exercises'] as List?) ?? const [];
    return list
        .map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<http.Response> _safePost(Uri uri, Map<String, dynamic> body) async {
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
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw AIServiceException('タイムアウトしました。通信環境を確認して再試行してください。');
    } catch (e) {
      throw AIServiceException('ネットワークエラーが発生しました。接続を確認してください。',
          detail: e.toString());
    }
    if (res.statusCode != 200) {
      String? apiDetail;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        final errObj = err['error'] as Map<String, dynamic>?;
        apiDetail = errObj?['message']?.toString();
      } catch (_) {}
      final msg = _mapStatusToMessage(res.statusCode, apiDetail);
      throw AIServiceException(msg, statusCode: res.statusCode, detail: apiDetail);
    }
    return res;
  }

  String _mapStatusToMessage(int status, String? apiDetail) {
    switch (status) {
      case 400:
        return 'リクエストが不正です。条件を短く具体的にしてください。';
      case 401:
        return '認証に失敗しました。APIキーが未設定/無効です。';
      case 403:
        return 'アクセスが拒否されました。権限設定を確認してください。';
      case 404:
        return 'リソースが見つかりません。モデル名やURLを確認してください。';
      case 429:
        return 'リクエストが多すぎます。時間をおいて再試行してください。';
      default:
        if (status >= 500) {
          return 'サーバー側で障害が発生しています。時間をおいて再試行してください。';
        }
        return 'エラーが発生しました。(HTTP $status)${apiDetail != null ? ' $apiDetail' : ''}';
    }
  }

  Future<List<TrainingMenu>> _generatePlansViaFunction(String userInput) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw AIServiceException('ログインが必要です。再ログインしてください。');
    }
    final idToken = await currentUser.getIdToken();
    final uri = Uri.parse(menuFunctionUrl!);

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'prompt': userInput}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw AIServiceException('タイムアウトしました。通信環境を確認して再試行してください。');
    } catch (e) {
      throw AIServiceException('ネットワークエラーが発生しました。接続を確認してください。',
          detail: e.toString());
    }

    if (res.statusCode != 200) {
      String? apiDetail;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        apiDetail = err['error']?.toString();
      } catch (_) {}
      throw AIServiceException('メニュー生成に失敗しました。',
          statusCode: res.statusCode, detail: apiDetail);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final text = data['text'] as String?;
    if (text == null || text.isEmpty) {
      throw AIServiceException('応答が空でした。条件を短く/具体的にして再試行してください。');
    }
    Map<String, dynamic> jsonObj;
    try {
      jsonObj = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      throw AIServiceException('応答の解析に失敗しました。もう一度お試しください。',
          detail: e.toString());
    }
    final List plans = (jsonObj['plans'] as List?) ?? const [];
    return plans
        .take(3)
        .map((e) => TrainingMenu.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class MockAIService implements AIServiceBase {
  @override
  Future<List<TrainingMenu>> generatePlans(String userInput) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final mock = {
      'plans': [
        {
          'name': '体幹＋下半身サーキット',
          'durationWeeks': 6,
          'daysPerWeek': 3,
          'intensity': 'やや中',
          'summary': '全身をバランスよく鍛えて代謝を上げる。',
          'exercises': [
            {
              'name': 'ウォームアップ(動的)',
              'sets': 1,
              'repsOrSeconds': '2分',
              'rest': '-',
              'notes': '関節を大きく動かす',
            },
            {
              'name': 'スクワット',
              'sets': 3,
              'repsOrSeconds': '12回',
              'rest': '45秒',
              'notes': '膝が内側に入らないように',
            },
          ],
          'caution': '痛みが出たら中止してください。',
        },
      ]
    };
    final plans = (mock['plans'] as List)
        .map((e) => TrainingMenu.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return plans;
  }

  @override
  Future<List<ExerciseItem>> generateExercises(String userInput) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final list = [
      {
        'name': 'スクワット',
        'sets': 3,
        'repsOrSeconds': '12回',
        'rest': '45秒',
        'notes': '背中をまっすぐに',
        'tips': ['膝が内側に入らない', 'つま先と膝の向きを揃える'],
        'steps': ['足を肩幅に開く', '腰を下げる', 'かかとで押して立つ'],
      },
      {
        'name': 'プランク',
        'sets': 3,
        'repsOrSeconds': '30秒',
        'rest': '45秒',
        'notes': '腰を反らさない',
        'tips': ['目線は床', '肩の真下に肘'],
        'steps': ['肘を床につく', '体を一直線に保つ', '呼吸を止めない'],
      },
    ];
    return list
        .map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
