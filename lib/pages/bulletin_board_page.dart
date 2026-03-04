import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_announcement_page.dart';
import 'dart:math';
import '../models/club.dart';
import '../services/role_service.dart';

class BulletinBoardPage extends StatefulWidget {
  final List<Club> clubs;
  const BulletinBoardPage({super.key, required this.clubs});

  @override
  State<BulletinBoardPage> createState() => _BulletinBoardPageState();
}

class _BulletinBoardPageState extends State<BulletinBoardPage> {
  final dbRef = FirebaseDatabase.instance.ref('announcements');
  List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;
  bool isAdmin = false;

  final List<Color> postItColors = [
    const Color(0xFFFFF59D), // Yellow
    const Color(0xFFFFCC80), // Orange
    const Color(0xFFEF9A9A), // Pink
    const Color(0xFFCE93D8), // Purple
    const Color(0xFF90CAF9), // Blue
    const Color(0xFFA5D6A7), // Green
    const Color(0xFFFFAB91), // Coral
  ];

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final adminClubs = await RoleService.getAdminClubs();
    setState(() {
      isAdmin = adminClubs.isNotEmpty;
    });
  }

  void fetchAnnouncements() {
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map<dynamic, dynamic>) {
        final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(data);
        final List<Map<String, dynamic>> loaded = [];

        map.forEach((key, value) {
          final entry = Map<String, dynamic>.from(value);
          loaded.add(entry);
        });

        loaded.sort(
            (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        setState(() {
          announcements = loaded;
          isLoading = false;
        });
      } else {
        setState(() {
          announcements = [];
          isLoading = false;
        });
      }
    });
  }

  String formatTimestamp(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return "${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  int getSizeCategory(String message) {
    final length = message.length;
    if (length < 50) return 1;
    if (length < 150) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF7A1E1E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF7A1E1E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📌 Bulletin Board',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (isAdmin)
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddAnnouncementPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle,
                              color: Colors.white, size: 32),
                        ),
                      IconButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: announcements.isEmpty
                    ? const Center(
                        child: Text(
                          'No announcements yet\nPin your first note! 📝',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: announcements.length,
                        itemBuilder: (context, index) {
                          final ann = announcements[index];
                          final message = ann['message'] ?? '';
                          final sizeCategory = getSizeCategory(message);
                          final color =
                              postItColors[index % postItColors.length];
                          final random = Random(index);
                          final rotation = (random.nextDouble() - 0.5) * 0.08;

                          return Transform.rotate(
                            angle: rotation,
                            child: PostItNote(
                              clubName: ann['clubName'] ?? 'Unknown Club',
                              postedBy: ann['postedBy'] ?? 'Anonymous',
                              message: message,
                              timestamp: formatTimestamp(ann['timestamp'] ?? 0),
                              color: color,
                              sizeCategory: sizeCategory,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostItNote extends StatelessWidget {
  final String clubName;
  final String postedBy;
  final String message;
  final String timestamp;
  final Color color;
  final int sizeCategory;

  const PostItNote({
    super.key,
    required this.clubName,
    required this.postedBy,
    required this.message,
    required this.timestamp,
    required this.color,
    this.sizeCategory = 2,
  });

  Map<String, double> getFontSizes() {
    switch (sizeCategory) {
      case 1:
        return {
          'clubName': 16.0,
          'postedBy': 12.0,
          'message': 14.0,
          'timestamp': 10.0,
        };
      case 2:
        return {
          'clubName': 14.0,
          'postedBy': 11.0,
          'message': 13.0,
          'timestamp': 9.0,
        };
      case 3:
        return {
          'clubName': 13.0,
          'postedBy': 10.0,
          'message': 12.0,
          'timestamp': 8.0,
        };
      default:
        return {
          'clubName': 14.0,
          'postedBy': 11.0,
          'message': 13.0,
          'timestamp': 9.0,
        };
    }
  }

  int getMaxLines() {
    switch (sizeCategory) {
      case 1:
        return 3;
      case 2:
        return 6;
      case 3:
        return 10;
      default:
        return 6;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = getFontSizes();

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Tape effect at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 30,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  clubName,
                  style: TextStyle(
                    fontSize: sizes['clubName'],
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF424242),
                    fontFamily: 'Courier',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '— $postedBy',
                  style: TextStyle(
                    fontSize: sizes['postedBy'],
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: sizes['message'],
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                    maxLines: getMaxLines(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: sizes['timestamp'],
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
