import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/workout.dart';
import 'workout_detail_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Stream<List<Workout>> get _workoutStream {
    return FirebaseFirestore.instance.collection('workouts').snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => Workout.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      },
    );
  }

  List<Workout> _getWorkoutsForDay(List<Workout> workouts, DateTime day) {
    return workouts.where((w) => isSameDay(w.date, day)).toList();
  }

  List<Map<String, dynamic>> _getWeeklyStats(List<Workout> workouts) {
    final today = DateTime.now();
    final last7Days =
        List.generate(7, (i) => today.subtract(Duration(days: i)));

    return last7Days
        .map((day) {
          final daily = _getWorkoutsForDay(workouts, day);
          final totalDuration =
              daily.fold<int>(0, (sum, w) => sum + w.duration);
          final totalCalories =
              daily.fold<int>(0, (sum, w) => sum + w.calories);
          return {
            'day': '${day.month}/${day.day}',
            'duration': totalDuration,
            'calories': totalCalories,
          };
        })
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー'), centerTitle: true),
      body: StreamBuilder<List<Workout>>(
        stream: _workoutStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final workouts = snapshot.data!;
          final selectedWorkouts = _selectedDay != null
              ? _getWorkoutsForDay(workouts, _selectedDay!)
              : [];
          final weeklyStats = _getWeeklyStats(workouts);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // 棒グラフ
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
                                  getTitlesWidget:
                                      (double value, TitleMeta meta) {
                                    int index = value.toInt();
                                    if (index < 0 ||
                                        index >= weeklyStats.length) {
                                      return const SizedBox();
                                    }
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        weeklyStats[index]['day'] as String,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            barGroups: weeklyStats.asMap().entries.map((entry) {
                              int index = entry.key;
                              final data = entry.value;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: (data['duration'] as num).toDouble(),
                                    color: Colors.deepPurple,
                                    width: 8,
                                  ),
                                  BarChartRodData(
                                    toY: (data['calories'] as num).toDouble(),
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
                          Text('運動時間（分）'),
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

                // デコレーション帯
                Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.deepPurpleAccent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'トレーニング概要',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                // カレンダー
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar<Workout>(
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
                    eventLoader: (day) => _getWorkoutsForDay(workouts, day),
                  ),
                ),

                const SizedBox(height: 16),

                // 選択日の運動一覧
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
                      if (selectedWorkouts.isEmpty)
                        const Text('この日に運動は登録されていません。'),
                      ...selectedWorkouts.map(
                        (workout) => Card(
                          child: ListTile(
                            title: Text(workout.name),
                            subtitle: Text(
                              '時間: ${workout.duration}分 | カロリー: ${workout.calories}kcal',
                            ),
                            trailing: const Icon(Icons.info_outline),
                            onTap: () =>
                                showWorkoutDetailDialog(context, workout),
                          ),
                        ),
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
}
