import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'workout_list_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final List<DateTime> _workoutDays = [
    DateTime(2025, 10, 10),
    DateTime(2025, 10, 11),
    DateTime(2025, 10, 14),
  ];

  bool _hasWorkoutOn(DateTime day) {
    return _workoutDays.any((d) => isSameDay(d, day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('運動カレンダー'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildCalendar(context),
            const SizedBox(height: 24),
            Text(
              _selectedDay == null
                  ? '日付をタップして運動記録を表示'
                  : '${_selectedDay!.month}/${_selectedDay!.day} の運動を確認できます',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ カレンダー描画部分
  Widget _buildCalendar(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

          if (_hasWorkoutOn(selectedDay)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutListScreen(date: selectedDay),
              ),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('この日は運動していません')));
          }
        },
        calendarFormat: CalendarFormat.month,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.purpleAccent,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(color: Colors.white),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (_hasWorkoutOn(day)) {
              return Positioned(
                bottom: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
