import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'add_announcement_page.dart';

class BulletinBoardPage extends StatefulWidget {
  const BulletinBoardPage({super.key});

  @override
  State<BulletinBoardPage> createState() => _BulletinBoardPageState();
}

class _BulletinBoardPageState extends State<BulletinBoardPage> {
  final dbRef = FirebaseDatabase.instance.ref('announcements');
  List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
  }

  void fetchAnnouncements() async {
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
    if (data != null && data is Map<dynamic, dynamic>) {
        final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(data);
        final List<Map<String, dynamic>> loaded = [];

        map.forEach((key, value) {
          final entry = Map<String, dynamic>.from(value);
          loaded.add(entry);
        });

        // Sort by timestamp descending (newest first)
        loaded.sort((a, b) => (b['timestamp'] as int)
            .compareTo(a['timestamp'] as int));

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
    return "${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📌 Bulletin Board'),
        backgroundColor: const Color(0xFF7A1E1E),
        centerTitle: true,
      ),
      body: announcements.isEmpty
          ? const Center(child: Text('No announcements yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final ann = announcements[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(ann['clubName'] ?? 'Unknown Club'),
                    subtitle: Text(ann['message'] ?? ''),
                    trailing: Text(
                      formatTimestamp(ann['timestamp'] ?? 0),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7A1E1E),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddAnnouncementPage(),
            ),
          );
        },
      ),
    );
  }
}
