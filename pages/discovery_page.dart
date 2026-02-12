
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
//       // Reference the 'clubs' node instead of root
//       final snapshot = await dbRef.child('clubs').get();
//       debugPrint('=== DEBUG INFO ===');
//       debugPrint('Snapshot exists: ${snapshot.exists}');

//       if (snapshot.exists) {
//         final data = snapshot.value;
//         final List<Club> loaded = [];

//         if (data is Map) {
//           data.forEach((key, value) {
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

//   void _showAddAnnouncementDialog() {
//     String? selectedClub;
//     final TextEditingController messageController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setDialogState) => AlertDialog(
//           title: const Text('Add Announcement'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Select Club',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 DropdownButtonFormField<String>(
//                   value: selectedClub,
//                   decoration: const InputDecoration(
//                     border: OutlineInputBorder(),
//                     hintText: 'Choose a club',
//                   ),
//                   items: clubs.map((club) {
//                     return DropdownMenuItem(
//                       value: club.name,
//                       child: Text(
//                         club.name,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     setDialogState(() {
//                       selectedClub = value;
//                     });
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Announcement Message',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 TextField(
//                   controller: messageController,
//                   decoration: const InputDecoration(
//                     border: OutlineInputBorder(),
//                     hintText: 'Enter your announcement',
//                   ),
//                   maxLines: 4,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 if (selectedClub != null && messageController.text.isNotEmpty) {
//                   try {
//                     await _addAnnouncement(selectedClub!, messageController.text);
//                     if (context.mounted) {
//                       Navigator.pop(context);
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('Announcement added successfully!'),
//                           backgroundColor: Colors.green,
//                         ),
//                       );
//                     }
//                   } catch (e) {
//                     if (context.mounted) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text('Error adding announcement: $e'),
//                           backgroundColor: Colors.red,
//                         ),
//                       );
//                     }
//                   }
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Please select a club and enter a message'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF7A1E1E),
//               ),
//               child: const Text('Post'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _addAnnouncement(String clubName, String message) async {
//     try {
//       final announcementsRef = dbRef.child('announcements');
      
//       // Create a new announcement with a push key
//       final newAnnouncementRef = announcementsRef.push();
      
//       await newAnnouncementRef.set({
//         'clubName': clubName,
//         'message': message,
//         'timestamp': ServerValue.timestamp,
//       });
      
//       debugPrint('Announcement added successfully');
//     } catch (e) {
//       debugPrint('Error adding announcement: $e');
//       rethrow;
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
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.campaign),
//             tooltip: 'Add Announcement',
//             onPressed: _showAddAnnouncementDialog,
//           ),
//         ],
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
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: _showAddAnnouncementDialog,
//         backgroundColor: const Color(0xFF7A1E1E),
//         icon: const Icon(Icons.campaign),
//         label: const Text('Announcement'),
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
  Map<String, String> clubAnnouncements = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClubsAndAnnouncements();
  }

  void fetchClubsAndAnnouncements() async {
    try {
      final clubsSnapshot = await dbRef.child('clubs').get();
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

      final announcementsSnapshot = await dbRef.child('announcements').get();
      Map<String, String> latestAnnouncements = {};

      if (announcementsSnapshot.exists) {
        final announcementsData = announcementsSnapshot.value;
        if (announcementsData is Map) {
          Map<String, Map<String, dynamic>> clubAnnouncementMap = {};

          announcementsData.forEach((key, value) {
            if (value != null && value is Map) {
              final announcement = Map<String, dynamic>.from(value);
              final clubName = announcement['clubName'] as String?;
              final timestamp = announcement['timestamp'] as int? ?? 0;
              final message = announcement['message'] as String? ?? '';

              if (clubName != null) {
                if (!clubAnnouncementMap.containsKey(clubName) ||
                    (clubAnnouncementMap[clubName]!['timestamp'] as int) <
                        timestamp) {
                  clubAnnouncementMap[clubName] = {
                    'message': message,
                    'timestamp': timestamp,
                  };
                }
              }
            }
          });

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

    // Calculate card height so exactly ~3 cards show on screen at once
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final availableHeight = screenHeight - appBarHeight;
    final cardHeight = availableHeight / 3.1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Discover Clubs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: clubs.length,
        itemBuilder: (context, index) {
          final club = clubs[index];
          final announcement = clubAnnouncements[club.name];
          final initial = club.head1 != null && club.head1!.isNotEmpty
              ? club.head1![0]
              : '?';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClubHomePage(club: club),
                ),
              );
            },
            child: Container(
              height: cardHeight,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF7A1E1E),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Club info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            club.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            club.advisor1 ?? 'No advisor listed',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (announcement != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF7A1E1E).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.campaign_outlined,
                                    size: 14,
                                    color: Color(0xFF7A1E1E),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      announcement,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF7A1E1E),
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
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}