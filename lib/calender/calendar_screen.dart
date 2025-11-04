import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart'; // グラフ用
import '../models/workout.dart';
import 'workout_detail_dialog.dart'; // 詳細ダイアログ

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 仮の運動データ
  final List<Workout> workouts = [
    Workout(
      name: 'ランニング',
      date: DateTime(2025, 10, 27),
      duration: 30,
      calories: 250,
    ),
    Workout(
      name: '筋トレ',
      date: DateTime(2025, 10, 28),
      duration: 45,
      calories: 300,
    ),
    Workout(
      name: 'ウォーキング',
      date: DateTime(2025, 10, 29),
      duration: 20,
      calories: 150,
    ),
  ];

  List<Workout> _getWorkoutsForDay(DateTime day) {
    return workouts.where((w) => isSameDay(w.date, day)).toList();
  }

  // 棒グラフ用データ（直近7日分）
  List<Map<String, dynamic>> get _weeklyStats {
    final today = DateTime.now();
    final last7Days = List.generate(
      7,
      (i) => today.subtract(Duration(days: i)),
    );

    return last7Days
        .map((day) {
          final daily = _getWorkoutsForDay(day);
          final totalDuration = daily.fold<int>(
            0,
            (sum, w) => sum + (w.duration ?? 0),
          );
          final totalCalories = daily.fold<int>(
            0,
            (sum, w) => sum + (w.calories ?? 0),
          );
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
    final selectedWorkouts =
        _selectedDay != null ? _getWorkoutsForDay(_selectedDay!) : [];

    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー'), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 🔹 棒グラフエリア
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
                                int index = value.toInt();
                                if (index < 0 || index >= _weeklyStats.length)
                                  return const SizedBox();
                                return Text(
                                  _weeklyStats[index]['day'],
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        barGroups: _weeklyStats.asMap().entries.map((entry) {
                          int index = entry.key;
                          final data = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: data['duration'].toDouble(),
                                color: Colors.deepPurple,
                                width: 8,
                              ),
                              BarChartRodData(
                                toY: (data['calories'] / 10).toDouble(),
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
                  // 🔹 凡例（紫＝運動時間、オレンジ＝消費カロリー）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.square,
                        color: Colors.deepPurple,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text('運動時間（分）'),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.square,
                        color: Colors.orangeAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text('消費カロリー（kcal）'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 カレンダー
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: TableCalendar(
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
                eventLoader: (day) => _getWorkoutsForDay(day),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 選択した日の運動一覧
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
                  if (selectedWorkouts.isEmpty) const Text('この日に運動は登録されていません。'),
                  ...selectedWorkouts.map(
                    (workout) => Card(
                      child: ListTile(
                        title: Text(workout.name),
                        subtitle: Text(
                          '時間: ${workout.duration}分 | カロリー: ${workout.calories}kcal',
                        ),
                        trailing: const Icon(Icons.info_outline),
                        onTap: () => showWorkoutDetailDialog(context, workout),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
