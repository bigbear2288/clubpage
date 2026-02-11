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
//       debugPrint('=== DEBUG INFO ===');
//       debugPrint('Snapshot exists: ${snapshot.exists}');

//       if (snapshot.exists) {
//         final data = snapshot.value;
//         final List<Club> loaded = [];

//         // Check if data is a List or Map
//         if (data is List) {
//           // Data is a list
//           for (var item in data) {
//             if (item != null) {
//               final Map<String, dynamic> clubMap =
//                   Map<String, dynamic>.from(item);
//               loaded.add(Club.fromMap(clubMap));
//             }
//           }
//         } else if (data is Map) {
//           // Data is a map
//           final mapData = data;
//           mapData.forEach((key, value) {
//             if (value != null) {
//               final Map<String, dynamic> clubMap =
//                   Map<String, dynamic>.from(value);
//               loaded.add(Club.fromMap(clubMap));
//             }
//           });
//         }

//         setState(() {
//           clubs = loaded;
//           isLoading = false;
//         });
//         debugPrint('Loaded ${loaded.length} clubs');
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
  Map<String, String> clubAnnouncements = {}; // Store latest announcement per club
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClubsAndAnnouncements();
  }

  void fetchClubsAndAnnouncements() async {
    try {
      // Fetch clubs from the 'clubs' node
      final clubsSnapshot = await dbRef.child('clubs').get();
      debugPrint('=== DEBUG INFO ===');
      debugPrint('Clubs snapshot exists: ${clubsSnapshot.exists}');

      final List<Club> loadedClubs = [];

      if (clubsSnapshot.exists) {
        final data = clubsSnapshot.value;

        if (data is Map) {
          data.forEach((key, value) {
            if (value != null) {
              final Map<String, dynamic> clubMap =
                  Map<String, dynamic>.from(value);
              loadedClubs.add(Club.fromMap(clubMap));
            }
          });
        }
      }

      // Fetch announcements
      final announcementsSnapshot = await dbRef.child('announcements').get();
      debugPrint('Announcements snapshot exists: ${announcementsSnapshot.exists}');

      Map<String, String> latestAnnouncements = {};

      if (announcementsSnapshot.exists) {
        final announcementsData = announcementsSnapshot.value;
        
        if (announcementsData is Map) {
          // Group announcements by club and get the most recent one
          Map<String, Map<String, dynamic>> clubAnnouncementMap = {};
          
          announcementsData.forEach((key, value) {
            if (value != null && value is Map) {
              final announcement = Map<String, dynamic>.from(value);
              final clubName = announcement['clubName'] as String?;
              final timestamp = announcement['timestamp'] as int? ?? 0;
              final message = announcement['message'] as String? ?? '';
              
              if (clubName != null) {
                // Check if this is the latest announcement for this club
                if (!clubAnnouncementMap.containsKey(clubName) ||
                    (clubAnnouncementMap[clubName]!['timestamp'] as int) < timestamp) {
                  clubAnnouncementMap[clubName] = {
                    'message': message,
                    'timestamp': timestamp,
                  };
                }
              }
            }
          });
          
          // Extract just the messages
          clubAnnouncementMap.forEach((clubName, data) {
            latestAnnouncements[clubName] = data['message'] as String;
          });
        }
      }

      setState(() {
        clubs = loadedClubs;
        clubAnnouncements = latestAnnouncements;
        isLoading = false;
      });
      
      debugPrint('Loaded ${loadedClubs.length} clubs');
      debugPrint('Loaded ${latestAnnouncements.length} announcements');
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() {
        isLoading = false;
        clubs = [];
        clubAnnouncements = {};
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
          final announcement = clubAnnouncements[club.name];
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(club.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.advisor1 ?? 'No advisor listed'),
                  if (announcement != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A1E1E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign,
                            size: 16,
                            color: Color(0xFF7A1E1E),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              announcement,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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