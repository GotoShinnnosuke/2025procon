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
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Stream<List<TrainingLogEntry>> _logStream(String uid) {
    return FirebaseFirestore.instance
        .collection('trainingLogs')
        .where('userId', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrainingLogEntry.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  List<TrainingLogEntry> _logsForDay(
      List<TrainingLogEntry> logs, DateTime day) {
    return logs.where((log) => isSameDay(log.completedAt, day)).toList();
  }

  DateTime _dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  List<DateTime> _chartDays(DateTime? selectedDay) {
    final today = _dateOnly(DateTime.now());
    if (selectedDay == null) {
      final start = today.subtract(const Duration(days: 30));
      return List.generate(31, (i) => start.add(Duration(days: i)));
    }
    final center = _dateOnly(selectedDay);
    final start = center.subtract(const Duration(days: 15));
    return List.generate(31, (i) => start.add(Duration(days: i)));
  }

  List<Map<String, dynamic>> _chartStats(
      List<TrainingLogEntry> logs, DateTime? selectedDay) {
    final days = _chartDays(selectedDay);
    return days.map((day) {
      final daily = _logsForDay(logs, day);
      final totalSets =
          daily.fold<int>(0, (sum, log) => sum + (log.sets ?? 0));
      final totalCalories =
          daily.fold<int>(0, (sum, log) => sum + (log.calories ?? 0));
      return {
        'day': '${day.month}/${day.day}',
        'sets': totalSets,
        'calories': totalCalories,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('カレンダー'), centerTitle: true),
        body: const Center(
          child: Text('トレーニング履歴を表示するにはログインしてください。'),
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

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const barWidth = 10.0;
                            const groupSpace = 12.0;
                            final desiredWidth =
                                stats.length * (barWidth * 2 + groupSpace);
                            final chartWidth =
                                desiredWidth < constraints.maxWidth
                                    ? constraints.maxWidth
                                    : desiredWidth;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: chartWidth,
                                child: BarChart(
                                  BarChartData(
                                    borderData: FlBorderData(show: false),
                                    groupsSpace: groupSpace,
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
                                              stats[index]['day'] as String,
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
                                            toY: (data['sets'] as int)
                                                .toDouble(),
                                            color: Colors.deepPurple,
                                            width: barWidth,
                                          ),
                                          BarChartRodData(
                                            toY: ((data['calories'] as int) /
                                                    10)
                                                .toDouble(),
                                            color: Colors.orangeAccent,
                                            width: barWidth,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDay == null
                            ? '日付を選択してください'
                            : '${_selectedDay!.month}/${_selectedDay!.day} のトレーニング履歴',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (visibleLogs.isEmpty)
                        const Text('この日に記録されたトレーニングはありません。'),
                      ...visibleLogs.map(
                        (log) {
                          final isPlan = log.isPlan;
                          final title = isPlan
                              ? '${log.planName ?? log.exerciseName} (プラン)'
                              : log.exerciseName;
                          final subtitle = isPlan
                              ? '種目数: ${log.planExercises.length} | 負荷: ${log.planIntensity ?? '-'}'
                              : 'セット: ${log.sets ?? '-'} | 回数/秒数: ${log.repsOrSeconds ?? '-'} | 負荷: ${log.loadLevel ?? '-'} | カロリー: ${log.calories ?? '-'}kcal';
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
                                      label: Text(isPlan ? 'プランを開く' : 'もう一度やる'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
