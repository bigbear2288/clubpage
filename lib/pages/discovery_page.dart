import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import 'club_home_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  // Reference to the root node of your Realtime Database
  final dbRef = FirebaseDatabase.instance.ref();
  List<Club> clubs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClubs();
  }

  void fetchClubs() async {
    try {
      final snapshot = await dbRef.get();
      debugPrint('=== DEBUG INFO ===');
      debugPrint('Snapshot exists: ${snapshot.exists}');

      if (snapshot.exists) {
        final data = snapshot.value;
        final List<Club> loaded = [];

        // Check if data is a List or Map
        if (data is List) {
          // Data is a list
          for (var item in data) {
            if (item != null) {
              final Map<String, dynamic> clubMap =
                  Map<String, dynamic>.from(item);
              loaded.add(Club.fromMap(clubMap));
            }
          }
        } else if (data is Map) {
          // Data is a map
          final mapData = data;
          mapData.forEach((key, value) {
            if (value != null) {
              final Map<String, dynamic> clubMap =
                  Map<String, dynamic>.from(value);
              loaded.add(Club.fromMap(clubMap));
            }
          });
        }

        setState(() {
          clubs = loaded;
          isLoading = false;
        });
        debugPrint('Loaded ${loaded.length} clubs');
      } else {
        setState(() {
          isLoading = false;
          clubs = [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching clubs: $e');
      setState(() {
        isLoading = false;
        clubs = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (clubs.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No clubs found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        backgroundColor: const Color(0xFF7A1E1E),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: clubs.length,
        itemBuilder: (context, index) {
          final club = clubs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(club.name),
              subtitle: Text(club.advisor1 ?? 'No advisor listed'),
              leading: club.head1 != null && club.head1!.isNotEmpty
                  ? CircleAvatar(child: Text(club.head1![0]))
                  : const Icon(Icons.group),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClubHomePage(club: club),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
