import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/training_log_entry.dart';
import '../fitnessDetail.dart';
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

  List<Map<String, dynamic>> _weeklyStats(List<TrainingLogEntry> logs) {
    final today = DateTime.now();
    final last7Days =
        List.generate(7, (index) => today.subtract(Duration(days: index)));

    return last7Days
        .map((day) {
          final daily = _logsForDay(logs, day);
          final totalSets = daily.fold<int>(0, (sum, log) => sum + (log.sets ?? 0));
          final totalCalories =
              daily.fold<int>(0, (sum, log) => sum + (log.calories ?? 0));
          return {
            'day': '${day.month}/${day.day}',
            'sets': totalSets,
            'calories': totalCalories,
          };
        })
        .toList()
        .reversed
        .toList();
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
          final stats = _weeklyStats(logs);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= stats.length) {
                                      return const SizedBox();
                                    }
                                    return Text(
                                      stats[index]['day'] as String,
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            barGroups: stats.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: (data['sets'] as int).toDouble(),
                                    color: Colors.deepPurple,
                                    width: 8,
                                  ),
                                  BarChartRodData(
                                    toY:
                                        ((data['calories'] as int) / 10).toDouble(),
                                    color: Colors.orangeAccent,
                                    width: 8,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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
                      if (selectedLogs.isEmpty)
                        const Text('この日に記録されたトレーニングはありません。'),
                      ...selectedLogs.map(
                        (log) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(log.exerciseName),
                                    subtitle: Text(
                                      'セット: ${log.sets ?? '-'} | 回数/秒数: ${log.repsOrSeconds ?? '-'} | 負荷: ${log.loadLevel ?? '-'} | カロリー: ${log.calories ?? '-'}kcal',
                                      maxLines: 2,
                                    ),
                                    trailing: const Icon(Icons.info_outline),
                                    onTap: () =>
                                        showWorkoutDetailDialog(context, log),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _navigateToDetail(log),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('もう一度やる'),
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
}
