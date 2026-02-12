// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../models/club.dart';
// import 'club_home_page.dart';

// class DiscoveryPage extends StatefulWidget {
//   const DiscoveryPage({super.key});

//   @override
//   State<DiscoveryPage> createState() => _DiscoveryPageState();
// }

// class _DiscoveryPageState extends State<DiscoveryPage> {
//   // Reference to the root node of your Realtime Database
//   final dbRef = FirebaseDatabase.instance.ref();
//   List<Club> clubs = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchClubs();
//   }

//   void fetchClubs() async {
//     try {
//       final snapshot = await dbRef.get();
//       debugPrint('Snapshot exists: ${snapshot.exists}');
//       debugPrint('Snapshot value: ${snapshot.value}');

//       if (snapshot.exists) {
//         final data = snapshot.value as Map<dynamic, dynamic>;
//         final List<Club> loaded = [];

//         data.forEach((key, value) {
//           // Each `value` is a map of the club's fields
//           final Map<String, dynamic> clubMap = Map<String, dynamic>.from(value);

//           // The "CLUB" field in your DB is the club's name
//           loaded.add(Club.fromMap(clubMap));
//         });

//         setState(() {
//           clubs = loaded;
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           isLoading = false;
//           clubs = [];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error fetching clubs: $e');
//       setState(() {
//         isLoading = false;
//         clubs = [];
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     if (clubs.isEmpty) {
//       return const Scaffold(
//         body: Center(child: Text('No clubs found')),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Clubs'),
//         backgroundColor: const Color(0xFF7A1E1E),
//       ),
//       body: ListView.builder(
//         padding: const EdgeInsets.all(12),
//         itemCount: clubs.length,
//         itemBuilder: (context, index) {
//           final club = clubs[index];
//           return Card(
//             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             child: ListTile(
//               title: Text(club.name),
//               subtitle: Text(club.advisor1 ?? 'No advisor listed'),
//               leading: club.head1 != null && club.head1!.isNotEmpty
//                   ? CircleAvatar(child: Text(club.head1![0]))
//                   : const Icon(Icons.group),
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => ClubHomePage(club: club),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }


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
      // Reference the 'clubs' node instead of root
      final snapshot = await dbRef.child('clubs').get();
      debugPrint('=== DEBUG INFO ===');
      debugPrint('Snapshot exists: ${snapshot.exists}');

      if (snapshot.exists) {
        final data = snapshot.value;
        final List<Club> loaded = [];

        if (data is Map) {
          data.forEach((key, value) {
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

  void _showAddAnnouncementDialog() {
    String? selectedClub;
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Club',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedClub,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Choose a club',
                  ),
                  items: clubs.map((club) {
                    return DropdownMenuItem(
                      value: club.name,
                      child: Text(
                        club.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedClub = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Announcement Message',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter your announcement',
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedClub != null && messageController.text.isNotEmpty) {
                  await _addAnnouncement(selectedClub!, messageController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Announcement added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a club and enter a message'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A1E1E),
              ),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAnnouncement(String clubName, String message) async {
    try {
      final announcementsRef = dbRef.child('announcements');
      
      // Create a new announcement with a push key
      final newAnnouncementRef = announcementsRef.push();
      
      await newAnnouncementRef.set({
        'clubName': clubName,
        'message': message,
        'timestamp': ServerValue.timestamp,
      });
      
      debugPrint('Announcement added successfully');
    } catch (e) {
      debugPrint('Error adding announcement: $e');
      rethrow;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Add Announcement',
            onPressed: _showAddAnnouncementDialog,
          ),
        ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAnnouncementDialog,
        backgroundColor: const Color(0xFF7A1E1E),
        icon: const Icon(Icons.campaign),
        label: const Text('Announcement'),
      ),
    );
  }
}