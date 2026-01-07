import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/club.dart';

class CalendarPage extends StatefulWidget {
  final List<Club> clubs;

  const CalendarPage({super.key, required this.clubs});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  /// TEMP LOGIC:
  /// Until schedules are stored in Firebase,
  /// we’ll just show all clubs on every day.
  List<Club> _meetingsForDay(DateTime day) {
    return widget.clubs;
  }

  List<Map<String, dynamic>> _upcomingMeetings() {
    final List<Map<String, dynamic>> upcoming = [];

    for (int i = 1; i <= 2; i++) {
      final day = _selectedDay!.add(Duration(days: i));
      for (var club in _meetingsForDay(day)) {
        upcoming.add({
          'club': club,
          'date': day,
          'daysAway': i,
        });
      }
    }
    return upcoming;
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final todayMeetings = _meetingsForDay(_selectedDay!);
    final upcoming = _upcomingMeetings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Club Calendar'),
        backgroundColor: const Color(0xFF7A1E1E),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar picker
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  )
                ],
              ),
              child: CalendarDatePicker(
                initialDate: _focusedDay,
                firstDate: DateTime.utc(2023, 1, 1),
                lastDate: DateTime.utc(2030, 12, 31),
                currentDate: DateTime.now(),
                onDateChanged: (selected) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = selected;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Meetings on selected day
            Text(
              'Clubs on ${_formatDate(_selectedDay!)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF7A1E1E),
              ),
            ),
            const SizedBox(height: 12),

            Column(
              children: todayMeetings.map((club) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(156, 43, 43, 1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      )
                    ],
                  ),
                  child: Text(
                    club.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Upcoming meetings
            if (upcoming.isNotEmpty) ...[
              const Text(
                'Upcoming Clubs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF7A1E1E),
                ),
              ),
              const SizedBox(height: 12),

              Column(
                children: upcoming.map((entry) {
                  final club = entry['club'] as Club;
                  final date = entry['date'] as DateTime;
                  final daysAway = entry['daysAway'] as int;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(156, 43, 43, 1),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                    child: Text(
                      '${club.name}\n${_formatDate(date)} • in $daysAway day${daysAway > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
