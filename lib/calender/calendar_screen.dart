import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/training_log_entry.dart';
import '../fitnessDetail.dart';
import '../plan_detail.dart';
import 'workout_detail_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _pendingScrollDay;

  final ScrollController _chartScrollController = ScrollController();

  static const double _barWidth = 10.0;
  static const double _groupSpace = 12.0;

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  Stream<List<TrainingLogEntry>> _logStream(String uid) {
    return FirebaseFirestore.instance
        .collection('trainingLogs')
        .where('userId', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrainingLogEntry.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  List<TrainingLogEntry> _logsForDay(
    List<TrainingLogEntry> logs,
    DateTime day,
  ) {
    return logs.where((log) => isSameDay(log.completedAt, day)).toList();
  }

  DateTime _dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  List<DateTime> _chartDays(DateTime? selectedDay) {
    final today = _dateOnly(DateTime.now());
    if (selectedDay == null) {
      final start = today.subtract(const Duration(days: 30));
      return List.generate(31, (i) => start.add(Duration(days: i)));
    }

    final selected = _dateOnly(selectedDay);
    final daysDiff = today.difference(selected).inDays;
    if (daysDiff <= 30) {
      final start = today.subtract(const Duration(days: 30));
      return List.generate(31, (i) => start.add(Duration(days: i)));
    }

    final start = selected.subtract(const Duration(days: 15));
    return List.generate(31, (i) => start.add(Duration(days: i)));
  }

  List<_ChartStat> _chartStats(
    List<TrainingLogEntry> logs,
    DateTime? selectedDay,
  ) {
    final days = _chartDays(selectedDay);
    return days.map((day) {
      final daily = _logsForDay(logs, day);
      final totalSets =
          daily.fold<int>(0, (sum, log) => sum + (log.sets ?? 0));
      final totalCalories =
          daily.fold<int>(0, (sum, log) => sum + (log.calories ?? 0));
      return _ChartStat(
        day: day,
        label: '${day.month}/${day.day}',
        sets: totalSets,
        calories: totalCalories,
      );
    }).toList();
  }

  int _indexForDay(List<DateTime> days, DateTime target) {
    return days.indexWhere((day) => isSameDay(day, target));
  }

  void _scheduleChartScroll(List<DateTime> days, double viewportWidth) {
    final target = _pendingScrollDay;
    if (target == null) return;
    final index = _indexForDay(days, target);
    if (index < 0) {
      _pendingScrollDay = null;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chartScrollController.hasClients) return;
      final groupExtent = _barWidth * 2 + _groupSpace;
      final rawOffset =
          index * groupExtent - (viewportWidth / 2 - groupExtent / 2);
      final maxOffset = _chartScrollController.position.maxScrollExtent;
      final clamped = rawOffset.clamp(0.0, maxOffset);
      _chartScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _pendingScrollDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('カレンダー'), centerTitle: true),
        body: const Center(
          child: Text('トレーニング履歴を見るにはログインしてください。'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー'), centerTitle: true),
      body: StreamBuilder<List<TrainingLogEntry>>(
        stream: _logStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('データの取得に失敗しました: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!;
          final selectedLogs =
              _selectedDay != null ? _logsForDay(logs, _selectedDay!) : [];
          final visibleLogs =
              selectedLogs.where((log) => !log.isPlanChild).toList();
          final stats = _chartStats(logs, _selectedDay);
          final chartDays = stats.map((e) => e.day).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // グラフ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final desiredWidth =
                                stats.length * (_barWidth * 2 + _groupSpace);
                            final chartWidth =
                                desiredWidth < constraints.maxWidth
                                    ? constraints.maxWidth
                                    : desiredWidth;
                            _scheduleChartScroll(
                              chartDays,
                              constraints.maxWidth,
                            );
                            return SingleChildScrollView(
                              controller: _chartScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: chartWidth,
                                child: BarChart(
                                  BarChartData(
                                    borderData: FlBorderData(show: false),
                                    groupsSpace: _groupSpace,
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 ||
                                                index >= stats.length) {
                                              return const SizedBox();
                                            }
                                            return Text(
                                              stats[index].label,
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    gridData:
                                        const FlGridData(show: false),
                                    barGroups:
                                        stats.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final data = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: data.sets.toDouble(),
                                            color: Colors.deepPurple,
                                            width: _barWidth,
                                          ),
                                          BarChartRodData(
                                            toY: data.calories / 10,
                                            color: Colors.orangeAccent,
                                            width: _barWidth,
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.square,
                              color: Colors.deepPurple, size: 16),
                          SizedBox(width: 4),
                          Text('セット数'),
                          SizedBox(width: 12),
                          Icon(Icons.square,
                              color: Colors.orangeAccent, size: 16),
                          SizedBox(width: 4),
                          Text('消費カロリー（kcal）'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // カレンダー
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar<TrainingLogEntry>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                        _pendingScrollDay = selectedDay;
                      });
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markerDecoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    eventLoader: (day) => _logsForDay(logs, day),
                  ),
                ),

                const SizedBox(height: 16),

                // 選択した日の運動一覧
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDay == null
                            ? '日付を選択してください'
                            : '${_selectedDay!.month}/${_selectedDay!.day} の運動一覧',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (visibleLogs.isEmpty)
                        const Text('この日に運動は登録されていません。'),
                      ...visibleLogs.map((log) {
                        final isPlan = log.isPlan;
                        final title = isPlan
                            ? '${log.planName ?? log.exerciseName}（プラン）'
                            : log.exerciseName;
                        final subtitle = isPlan
                            ? '種目数: ${log.planExercises.length}'
                                ' | 負荷: ${log.planIntensity ?? '-'}'
                                '${log.planMinutes != null ? ' | 時間: ${log.planMinutes}分' : ''}'
                            : 'セット: ${log.sets ?? '-'}'
                                ' | 回数/秒数: ${log.repsOrSeconds ?? '-'}'
                                ' | 負荷: ${log.loadLevel ?? '-'}'
                                ' | カロリー: ${log.calories ?? '-'}kcal';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(title),
                                  subtitle: Text(subtitle, maxLines: 2),
                                  trailing: const Icon(Icons.info_outline),
                                  onTap: () {
                                    if (isPlan) {
                                      _navigateToPlanDetail(log);
                                    } else {
                                      showWorkoutDetailDialog(context, log);
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: () => isPlan
                                        ? _navigateToPlanDetail(log)
                                        : _navigateToDetail(log),
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(isPlan ? 'プランを見る' : 'もう一度やる'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToDetail(TrainingLogEntry log) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessDetailPage(exercise: log.toExerciseItem()),
      ),
    );
  }

  void _navigateToPlanDetail(TrainingLogEntry log) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDetailPage(
          plan: log.toPlan(),
          minutes: log.planMinutes,
        ),
      ),
    );
  }
}

class _ChartStat {
  const _ChartStat({
    required this.day,
    required this.label,
    required this.sets,
    required this.calories,
  });

  final DateTime day;
  final String label;
  final int sets;
  final int calories;
}
