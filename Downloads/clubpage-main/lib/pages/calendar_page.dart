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
  Set<String> myClubIds = {};
  List<Club> allClubs = [];

  static const Map<String, Color> blockColors = {
    'Mon HS Flex': Color(0xFFEF9A9A),
    'Tue HS Flex': Color(0xFFFFCC80),
    'Wed HS Flex': Color(0xFFFFF59D),
    'Thu HS Flex': Color(0xFFA5D6A7),
    'Fri HS Flex': Color(0xFF90CAF9),
  };

  static const List<String> flexOptions = [
    'Mon HS Flex',
    'Tue HS Flex',
    'Wed HS Flex',
    'Thu HS Flex',
    'Fri HS Flex',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _listenToFollowedClubs();
    _listenToMyClubs();
    _fetchClubs();
  }

  void _fetchClubs() {
    FirebaseDatabase.instance.ref('clubs').onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        final List<Club> loaded = [];
        data.forEach((key, value) {
          if (value != null && value is Map) {
            final clubMap = Map<String, dynamic>.from(value);
            clubMap['name'] = key.toString();
            loaded.add(Club.fromMap(clubMap));
          }
        });
        setState(() {
          allClubs = loaded;
        });
      }
    });
  }

  void _listenToFollowedClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    FirebaseDatabase.instance
        .ref('users/$userKey/followedClubs')
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

  void _listenToMyClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    FirebaseDatabase.instance
        .ref('users/$userKey/myClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      setState(() {
        if (data is Map) {
          myClubIds = data.keys.cast<String>().toSet();
        } else {
          myClubIds = {};
        }
      });
    });
  }

  Set<String> get allClubIds => {...followedClubIds, ...myClubIds};

  List<Club> get followedClubs =>
      allClubs.where((c) => allClubIds.contains(c.name)).toList();

  // Filter clubs that meet on the selected day based on schedule field
  List<Club> _clubsForDay(DateTime day) {
    final dayName = DateFormat('EEE').format(day); // e.g. "Mon"

    return followedClubs.where((club) {
      final blocksStr = club.meetingBlock ?? '';
      final blocks =
          blocksStr.isNotEmpty ? blocksStr.split(', ').toSet() : <String>{};

      if (blocks.isEmpty && (club.schedule == null || club.schedule!.isEmpty)) {
        return false;
      }

      // Check for HS Flex on specific days
      final flexPrefix = dayName.substring(0, 3); // "Mon", "Tue", etc.
      final flexOption = '$flexPrefix HS Flex';
      if (blocks.contains(flexOption)) return true;

      // Check schedule days
      if (club.schedule != null && club.schedule!.isNotEmpty) {
        return club.schedule!.contains(dayName);
      }

      // No matching meeting time for this day
      return false;
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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
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
                      children: flexOptions.map((flex) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: blockColors[flex],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            flex.replaceAll(' HS Flex', ''),
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

            // Clubs on selected day
            Text(
              'Your Clubs on ${_formatDate(_selectedDay!)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF7A1E1E),
              ),
            ),
            const SizedBox(height: 12),

            followedClubIds.isEmpty && myClubIds.isEmpty
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
                    : todayClubs.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'None of your followed clubs meet on this day.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          )
                        : Column(
                            children: todayClubs.map((club) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: club.clubColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                      offset: Offset(1, 1),
                                    )
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
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (club.schedule != null &&
                                        club.schedule!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          club.schedule!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
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
