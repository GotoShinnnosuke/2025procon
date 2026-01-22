import 'package:flutter/material.dart';
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

  // 🔹 Firebaseからのデータ読み込み用（現在は仮データ）
  final List<Workout> workouts = [
    Workout(name: 'ランニング', date: DateTime.now(), duration: 30, calories: 250),
    Workout(name: '筋トレ', date: DateTime.now().subtract(const Duration(days: 1)), duration: 45, calories: 300),
  ];

  @override
  void initState() {
    super.initState();
    // 🔹 起動時に「今日」を選択状態にする
    _selectedDay = _focusedDay;
  }

  List<Workout> _getWorkoutsForDay(DateTime day) {
    return workouts.where((w) => isSameDay(w.date, day)).toList();
  }

  // 指定された週の7日間データを取得
  List<Map<String, dynamic>> _getWeeklyStats(int weekOffset) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: (weekOffset * 7) + (6 - i)));
      final daily = _getWorkoutsForDay(day);
      return {
        'day': '${day.month}/${day.day}',
        'duration': daily.fold<int>(0, (sum, w) => sum + (w.duration ?? 0)),
        'calories': daily.fold<int>(0, (sum, w) => sum + (w.calories ?? 0)),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 _selectedDay が初期値（今日）を持っているので、最初からリストが作成される
    final List<Workout> selectedWorkouts = _selectedDay != null ? _getWorkoutsForDay(_selectedDay!) : [];

    return Scaffold(
      appBar: AppBar(title: const Text('トレーニング記録'), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 1週間ごとのスライドグラフ
            SizedBox(
              height: 300, 
              child: PageView.builder(
                reverse: true,
                itemCount: 5,
                itemBuilder: (context, index) {
                  final weeklyData = _getWeeklyStats(index);
                  return _buildWeeklyChartCard(weeklyData, index == 0 ? "今週" : "$index週間前");
                },
              ),
            ),
            _buildLegend(),
            const SizedBox(height: 20),
            _buildCalendar(),
            const SizedBox(height: 20),
            // 🔹 ここに今日（または選択した日）のリストが出る
            _buildWorkoutList(selectedWorkouts),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChartCard(List<Map<String, dynamic>> stats, String title) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: 120,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        int i = value.toInt();
                        if (i < 0 || i >= stats.length) return const SizedBox();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(stats[i]['day'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: stats.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['duration'].toDouble(),
                        color: const Color.fromARGB(255, 102, 198, 198),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      BarChartRodData(
                        toY: (entry.value['calories'] / 10).toDouble(),
                        color: const Color.fromARGB(255, 103, 218, 139),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: TableCalendar<Workout>(
        firstDay: DateTime.now().subtract(const Duration(days: 90)),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() { 
            _selectedDay = selected; 
            _focusedDay = focused; 
          });
        },
        eventLoader: (DateTime day) => _getWorkoutsForDay(day),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      ),
    );
  }

  Widget _buildWorkoutList(List<Workout> selectedWorkouts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedDay == null 
                ? '日付を選択してください' 
                : isSameDay(_selectedDay, DateTime.now()) 
                    ? '今日の運動' 
                    : '${_selectedDay!.month}/${_selectedDay!.day} の運動',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (selectedWorkouts.isEmpty) 
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('運動の記録がありません', style: TextStyle(color: Colors.grey)),
            )
          else
            ...selectedWorkouts.map((w) => Card(
              elevation: 0,
              color: Colors.grey[50],
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.deepPurpleAccent),
                title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${w.duration}分 / ${w.calories}kcal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showWorkoutDetailDialog(context, w),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(const Color.fromARGB(255, 102, 198, 198)), const Text(' 時間(分)', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 20),
        _dot(const Color.fromARGB(255, 103, 218, 139)), const Text(' カロリー(10kcal)', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}