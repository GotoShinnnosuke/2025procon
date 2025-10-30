class Workout {
  final String name; // 種類（ランニング、筋トレなど）
  final DateTime date; // 実施日
  final int duration; // 運動時間（分）
  final int calories; // 消費カロリー（kcal）

  Workout({
    required this.name,
    required this.date,
    required this.duration,
    required this.calories,
  });
}
