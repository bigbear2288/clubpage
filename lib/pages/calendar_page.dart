import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  Set<String> followedClubIds = {};

  static const Map<String, Color> blockColors = {
    'A': Color(0xFFEF9A9A),
    'B': Color(0xFFFFCC80),
    'C': Color(0xFFFFF59D),
    'D': Color(0xFFA5D6A7),
    'E': Color(0xFF90CAF9),
    'F': Color(0xFFCE93D8),
    'G': Color(0xFF80DEEA),
    'H': Color(0xFFFFAB91),
    'Activities': Color(0xFFB0BEC5),
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _listenToFollowedClubs();
  }

  void _listenToFollowedClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref('users/${user.uid}/followedClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      setState(() {
        if (data is Map) {
          followedClubIds = data.keys.cast<String>().toSet();
        } else {
          followedClubIds = {};
        }
      });
    });
  }

  List<Club> get followedClubs =>
      widget.clubs.where((c) => followedClubIds.contains(c.name)).toList();

  // Filter clubs that meet on the selected day based on schedule field
  List<Club> _clubsForDay(DateTime day) {
    final dayName = DateFormat('EEE').format(day); // e.g. "Mon"
    // Activities block only on Wednesdays
    final isWednesday = day.weekday == DateTime.wednesday;

    return followedClubs.where((club) {
      if (club.meetingBlock == null &&
          (club.schedule == null || club.schedule!.isEmpty)) {
        return false;
      }
      // If it's Activities block, only show on Wednesdays
      if (club.meetingBlock == 'Activities') return isWednesday;
      // Check schedule days
      if (club.schedule != null && club.schedule!.isNotEmpty) {
        return club.schedule!.contains(dayName);
      }
      // If no schedule set but has a block, show every weekday
      return day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
    }).toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final todayClubs = _clubsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF7A1E1E),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Block color legend
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Block Legend',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: blockColors.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: entry.value,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Calendar picker
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(2, 2))
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

            Text(
              'Your Clubs on ${_formatDate(_selectedDay!)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF7A1E1E),
              ),
            ),
            const SizedBox(height: 12),

            followedClubIds.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Follow clubs on the Discovery page to see them here!',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : todayClubs.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'None of your followed clubs meet on this day.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : Column(
                        children: todayClubs.map((club) {
                          final block = club.meetingBlock;
                          final color = block != null
                              ? blockColors[block] ?? Colors.grey[200]!
                              : const Color.fromRGBO(156, 43, 43, 1);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: Offset(1, 1))
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    club.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF424242),
                                    ),
                                  ),
                                ),
                                if (block != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$block Block',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF424242)),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }
}
