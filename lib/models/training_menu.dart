class ExerciseItem {
  final String name;
  final int? sets;
  final String? repsOrSeconds;
  final String? rest;
  final String? notes;
  final List<String> tips; // コツ
  final List<String> steps; // 手順
  final int? calories; // 推定消費カロリー（kcal）
  final String? imageUrl;
  final String? videoUrl;

  ExerciseItem({
    required this.name,
    this.sets,
    this.repsOrSeconds,
    this.rest,
    this.notes,
    this.tips = const [],
    this.steps = const [],
    this.calories,
    this.imageUrl,
    this.videoUrl,
  });

  factory ExerciseItem.fromJson(Map<String, dynamic> j) => ExerciseItem(
        name: j['name']?.toString() ?? '',
        sets: j['sets'] is int ? j['sets'] as int : int.tryParse('${j['sets']}'),
        repsOrSeconds: j['repsOrSeconds']?.toString(),
        rest: j['rest']?.toString(),
        notes: j['notes']?.toString(),
        tips: (j['tips'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        steps: (j['steps'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        calories: j['calories'] is int
            ? j['calories'] as int
            : int.tryParse('${j['calories']}'),
        imageUrl: j['imageUrl']?.toString(),
        videoUrl: j['videoUrl']?.toString(),
      );
}

class TrainingMenu {
  final String name;
  final int? durationWeeks;
  final int? daysPerWeek;
  final String? intensity;
  final String? summary;
  final List<ExerciseItem> exercises;
  final String? caution;

  TrainingMenu({
    required this.name,
    this.durationWeeks,
    this.daysPerWeek,
    this.intensity,
    this.summary,
    this.exercises = const [],
    this.caution,
  });

  factory TrainingMenu.fromJson(Map<String, dynamic> j) => TrainingMenu(
        name: j['name']?.toString() ?? 'プラン',
        durationWeeks: j['durationWeeks'] is int
            ? j['durationWeeks'] as int
            : int.tryParse('${j['durationWeeks']}'),
        daysPerWeek: j['daysPerWeek'] is int
            ? j['daysPerWeek'] as int
            : int.tryParse('${j['daysPerWeek']}'),
        intensity: j['intensity']?.toString(),
        summary: j['summary']?.toString(),
        exercises: (j['exercises'] as List?)
                ?.map((e) => ExerciseItem.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        caution: j['caution']?.toString(),
      );
}

