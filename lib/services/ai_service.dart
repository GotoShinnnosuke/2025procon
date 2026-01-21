import 'dart:convert';
import 'dart:async';
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
  String toString() =>
      statusCode == null ? message : '$message (HTTP ${statusCode}${detail != null ? ': $detail' : ''})';
}

class OpenAIAIService implements AIServiceBase {
  final String apiKey;
  final String? baseUrl; // Optional override for proxy/backend

  OpenAIAIService({required this.apiKey, this.baseUrl});

  @override
  Future<List<TrainingMenu>> generatePlans(String userInput) async {
    if (apiKey.isEmpty) {
      throw AIServiceException('APIキーが未設定です。--dart-define=OPENAI_API_KEY=... を指定してください。');
    }

    final uri = Uri.parse((baseUrl ?? 'https://api.openai.com') + '/v1/chat/completions');
    final body = {
      'model': 'gpt-4o-mini',
      'temperature': 0.7,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'あなたは認定パーソナルトレーナー。安全第一。関節痛や既往歴に配慮すること。必ずJSONのみを返す。構造は {"plans":[{name,durationWeeks,daysPerWeek,intensity,summary,exercises:[{name,sets,repsOrSeconds,rest,notes,tips:[string],steps:[string]}],caution}] }。日本語で簡潔に。steps/tips/notesは足・手の置き方、動作方向、姿勢、呼吸、よくあるNGを短い文で具体的に書く。器具は使用不可（自重のみ）。ダンベル/バーベル/ケトルベル/マシン等の器具名は含めない。必ず3案返すこと。'
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
      throw AIServiceException('ネットワークエラーが発生しました。接続を確認してください。', detail: e.toString());
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
      throw AIServiceException('応答の解析に失敗しました。もう一度お試しください。', detail: e.toString());
    }
    final List plans = (jsonObj['plans'] as List?) ?? const [];
    return plans.take(3).map((e) => TrainingMenu.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<List<ExerciseItem>> generateExercises(String userInput) async {
    if (apiKey.isEmpty) {
      throw AIServiceException('APIキーが未設定です。--dart-define=OPENAI_API_KEY=... を指定してください。');
    }

    final uri = Uri.parse((baseUrl ?? 'https://api.openai.com') + '/v1/chat/completions');
    final body = {
      'model': 'gpt-4o-mini',
      'temperature': 0.7,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'あなたは認定パーソナルトレーナー。安全第一。必ずJSONのみを返す。構造は {"exercises":[{name,sets,repsOrSeconds,rest,notes,calories,tips:[string],steps:[string]}] }。日本語で簡潔に。関節や既往歴に配慮し、過負荷にならないよう調整案もnotesに記載。steps/tips/notesは足・手の置き方、動作方向、姿勢、呼吸、よくあるNGを短い文で具体的に書く。器具は使用不可（自重のみ）。ダンベル/バーベル/ケトルベル/マシン/チューブ等の器具名を含めない。必要なら床・壁・タオル程度の身近な物のみ可。各種目は推定消費カロリー(calories: 整数, 単位kcal)を含める。必ず10件以内で返すこと。'
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
      throw AIServiceException('応答の解析に失敗しました。もう一度お試しください。', detail: e.toString());
    }
    final List list = (jsonObj['exercises'] as List?) ?? const [];
    return list.map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e))).toList();
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
      throw AIServiceException('ネットワークエラーが発生しました。接続を確認してください。', detail: e.toString());
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
        return 'リクエストが不正です。入力が長すぎる/形式に誤りがある可能性があります。';
      case 401:
        return '認証に失敗しました。APIキーが不正または未設定です。';
      case 403:
        return 'アクセスが拒否されました。権限不足または課金設定をご確認ください。';
      case 404:
        return 'リソースが見つかりません。モデル名の誤りの可能性があります。';
      case 429:
        return 'レート制限/クォータ超過です。時間をおいて再試行してください。';
      default:
        if (status >= 500) {
          return 'サーバー側で問題が発生しています。時間をおいて再試行してください。';
        }
        return 'エラーが発生しました。(HTTP $status)${apiDetail != null ? ' $apiDetail' : ''}';
    }
  }
}

class MockAIService implements AIServiceBase {
  @override
  Future<List<TrainingMenu>> generatePlans(String userInput) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final mock = {
      'plans': [
        {
          'name': '初心者・自重サーキット',
          'durationWeeks': 6,
          'daysPerWeek': 3,
          'intensity': 'やや低〜中',
          'summary': '全身をバランスよく動かして脂肪燃焼。膝関節に優しい構成。',
          'exercises': [
            {'name': 'ウォームアップ(足踏み)', 'sets': 1, 'repsOrSeconds': '2分', 'rest': '—', 'notes': '呼吸を整える'},
            {'name': 'スクワット(浅め)', 'sets': 3, 'repsOrSeconds': '12回', 'rest': '45秒', 'notes': '膝はつま先より前に出しすぎない'},
            {'name': '膝つきプッシュアップ', 'sets': 3, 'repsOrSeconds': '8〜10回', 'rest': '60秒', 'notes': '体を一直線に'},
            {'name': 'グルートブリッジ', 'sets': 3, 'repsOrSeconds': '12回', 'rest': '45秒', 'notes': 'お尻を締める'},
            {'name': 'プランク', 'sets': 2, 'repsOrSeconds': '30秒', 'rest': '45秒', 'notes': '腰を反らさない'},
          ],
          'caution': '痛みが出たら即中止。ウォームアップとクールダウンを徹底。',
        },
        {
          'name': '脂肪燃焼・有酸素メイン',
          'durationWeeks': 8,
          'daysPerWeek': 4,
          'intensity': '中',
          'summary': '低衝撃の有酸素を中心に脂肪燃焼を最大化。',
          'exercises': [
            {'name': '早歩き/踏み台昇降', 'sets': 1, 'repsOrSeconds': '20分', 'rest': '—', 'notes': '会話できる強度'},
            {'name': 'バードドッグ', 'sets': 2, 'repsOrSeconds': '左右各10回', 'rest': '45秒', 'notes': '体幹安定'},
            {'name': 'ヒップヒンジ(自重デッドリフト)', 'sets': 3, 'repsOrSeconds': '12回', 'rest': '60秒', 'notes': '腰丸めない'},
          ],
          'caution': '息切れが強い日は時間を半分に調整。',
        },
        {
          'name': '下半身フォーカス・関節ケア',
          'durationWeeks': 6,
          'daysPerWeek': 3,
          'intensity': '低〜中',
          'summary': '膝に優しい可動域で筋力と安定性を向上。',
          'exercises': [
            {'name': 'ウォールスクワット(浅め)', 'sets': 3, 'repsOrSeconds': '10回', 'rest': '60秒', 'notes': '壁を背にフォーム意識'},
            {'name': 'カーフレイズ', 'sets': 3, 'repsOrSeconds': '15回', 'rest': '45秒', 'notes': 'ゆっくり'},
            {'name': 'サイドレッグレイズ', 'sets': 2, 'repsOrSeconds': '左右各12回', 'rest': '45秒', 'notes': '骨盤を安定'},
            {'name': 'サイドプランク(膝つき)', 'sets': 2, 'repsOrSeconds': '20秒', 'rest': '45秒', 'notes': '呼吸を止めない'},
          ],
          'caution': '痛みや違和感がある可動域は避ける。',
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
        'notes': '膝はつま先より前に出しすぎない',
        'tips': ['胸を張る', 'かかと重心でしゃがむ', '膝は内側に入れない'],
        'steps': ['肩幅に立つ', 'お尻を引きながらしゃがむ', 'かかとで床を押して立ち上がる']
      },
      {
        'name': 'プランク',
        'sets': 3,
        'repsOrSeconds': '30秒',
        'rest': '45秒',
        'notes': '腰を反らさない',
        'tips': ['体を一直線に保つ', 'お腹に軽く力を入れる'],
        'steps': ['肘とつま先で支える', '肩の真下に肘を置く', '呼吸を続ける']
      },
      {
        'name': '膝つきプッシュアップ',
        'sets': 3,
        'repsOrSeconds': '8〜10回',
        'rest': '60秒',
        'notes': '体を一直線に',
        'tips': ['肘をやや外に', '下で反動を使わない'],
        'steps': ['膝をついて腕立ての姿勢', '胸が床に近づくまで下降', '押し上げて戻る']
      },
    ];
    return list.map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
