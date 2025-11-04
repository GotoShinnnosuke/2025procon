class Workout {
  final String name;
  final DateTime? date; // 日付（カレンダー用）
  final int? duration; // 分（数値、グラフ計算用）
  final int? calories; // kcal
  final String? durationLabel; // 表示用の文字列（例: "10分"）
  final String? imageUrl;
  final String? description;

  Workout({
    required this.name,
    this.date,
    this.duration,
    this.calories,
    this.durationLabel,
    this.imageUrl,
    this.description,
  });
}
