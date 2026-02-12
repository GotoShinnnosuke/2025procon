import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../fitnessDetail.dart';
import '../models/training_log_entry.dart';
import '../plan_detail.dart';
import '../share/share_service.dart';
import '../share/share_templates.dart';
import 'workout_detail_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  Stream<List<TrainingLogEntry>> _logStream(String uid) {
    return FirebaseFirestore.instance
        .collection('trainingLogs')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final entries = snap.docs
          .map((d) {
            final data = d.data();
            if (data['deleted'] == true) return null;
            return TrainingLogEntry.fromFirestore(data, d.id);
          })
          .whereType<TrainingLogEntry>()
          .toList();
      entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return entries;
    });
  }

  List<TrainingLogEntry> _visibleLogs(List<TrainingLogEntry> logs) {
    return logs.where((log) => !log.isPlanChild).toList();
  }

  List<TrainingLogEntry> _getLogsForDay(
      List<TrainingLogEntry> logs, DateTime day) {
    return logs.where((log) => isSameDay(log.completedAt, day)).toList();
  }

  List<Map<String, dynamic>> _getWeeklyStats(
      List<TrainingLogEntry> logs, int weekOffset) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: (weekOffset * 7) + (6 - i)));
      final daily = _getLogsForDay(logs, day);
      final totalSets =
          daily.fold<int>(0, (sum, w) => sum + (w.sets ?? 0));
      final totalCalories =
          daily.fold<int>(0, (sum, w) => sum + (w.calories ?? 0));
      return {
        'day': '${day.month}/${day.day}',
        'sets': totalSets,
        'calories': totalCalories,
      };
    });
  }

  ShareData _shareDataForLog(TrainingLogEntry log) {
    final title = log.isPlan
        ? (log.planName ?? log.exerciseName)
        : log.exerciseName;
    final parts = <String>[];
    if (log.sets != null) parts.add('セット ${log.sets}');
    if (log.repsOrSeconds != null && log.repsOrSeconds!.isNotEmpty) {
      parts.add('回数/秒 ${log.repsOrSeconds}');
    }
    if (log.loadLevel != null && log.loadLevel!.isNotEmpty) {
      parts.add('負荷 ${log.loadLevel}');
    }
    final detail = parts.isEmpty ? '' : ' (${parts.join(' / ')})';
    return ShareTemplates.plain(message: '$title を完了しました$detail');
  }

  void _openLog(TrainingLogEntry log) {
    if (log.isPlan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanDetailPage(
            plan: log.toPlan(),
            minutes: log.planMinutes,
          ),
        ),
      );
      return;
    }
    showWorkoutDetailDialog(context, log);
  }

  void _runAgain(TrainingLogEntry log) {
    if (log.isPlan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanDetailPage(
            plan: log.toPlan(),
            minutes: log.planMinutes,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessDetailPage(
          exercise: log.toExerciseItem(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('トレーニング記録'), centerTitle: true),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return StreamBuilder<List<TrainingLogEntry>>(
      stream: _logStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar:
                AppBar(title: const Text('トレーニング記録'), centerTitle: true),
            body: Center(child: Text('読み込みに失敗しました: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final List<TrainingLogEntry> logs =
            _visibleLogs(snapshot.data ?? const <TrainingLogEntry>[]);
        final List<TrainingLogEntry> selectedLogs = _selectedDay != null
            ? _getLogsForDay(logs, _selectedDay!)
            : <TrainingLogEntry>[];

        return Scaffold(
          appBar: AppBar(title: const Text('トレーニング記録'), centerTitle: true),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    reverse: true,
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final weeklyStats = _getWeeklyStats(logs, index);
                      final title = index == 0 ? '今週' : '${index}週間前';
                      return _buildWeeklyChartCard(weeklyStats, title);
                    },
                  ),
                ),
                _buildLegend(),
                const SizedBox(height: 20),
                _buildCalendar(logs),
                const SizedBox(height: 20),
                _buildWorkoutList(selectedLogs),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyChartCard(List<Map<String, dynamic>> stats, String title) {
    final maxValue = stats.fold<double>(0, (prev, e) {
      final sets = (e['sets'] ?? 0).toDouble();
      final calories = ((e['calories'] ?? 0) / 10).toDouble();
      return [prev, sets, calories].reduce((a, b) => a > b ? a : b);
    });
    final maxY = maxValue <= 0 ? 10.0 : maxValue + 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= stats.length) {
                          return const SizedBox();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            stats[i]['day'],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                        toY: (entry.value['sets'] ?? 0).toDouble(),
                        color: const Color.fromARGB(255, 102, 198, 198),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      BarChartRodData(
                        toY: ((entry.value['calories'] ?? 0) / 10).toDouble(),
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

  Widget _buildCalendar(List<TrainingLogEntry> logs) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: TableCalendar<TrainingLogEntry>(
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
        eventLoader: (day) => _getLogsForDay(logs, day),
        calendarStyle: const CalendarStyle(
          todayDecoration:
              BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          selectedDecoration:
              BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
          markerDecoration:
              BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
      ),
    );
  }

  Widget _buildWorkoutList(List<TrainingLogEntry> selectedLogs) {
    final title = _selectedDay == null
        ? '日付を選択してください'
        : isSameDay(_selectedDay, DateTime.now())
            ? '今日の運動'
            : '${_selectedDay!.month}/${_selectedDay!.day} の運動';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (selectedLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '運動の記録がありません',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...selectedLogs.map((log) {
              final shareData = _shareDataForLog(log);
              final subtitle = log.isPlan
                  ? 'プラン / ${log.planMinutes ?? '-'}分'
                  : '${log.sets ?? '-'}セット / ${log.calories ?? '-'}kcal';
              return Card(
                elevation: 0,
                color: Colors.grey[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    log.isPlan
                        ? Icons.calendar_view_day
                        : Icons.fitness_center,
                    color: Colors.deepPurpleAccent,
                  ),
                  title: Text(
                    log.isPlan
                        ? (log.planName ?? log.exerciseName)
                        : log.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subtitle),
                  trailing: SizedBox(
                    width: 72,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () => ShareService.share(
                            text: shareData.text,
                            url: shareData.url,
                            hashtags: shareData.hashtags,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  onTap: () => _openLog(log),
                  onLongPress: () => _runAgain(log),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(const Color.fromARGB(255, 102, 198, 198)),
        const Text(' セット数', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 20),
        _dot(const Color.fromARGB(255, 103, 218, 139)),
        const Text(' カロリー(10kcal)', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
