import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../services/user_service.dart';
import 'club_home_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  List<Club> clubs = [];
  Set<String> followedClubIds = {};
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchClubs();
    loadFollowedClubs();
  }

  Future<void> loadFollowedClubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/followedClubs')
          .get();

      if (userSnapshot.exists && userSnapshot.value != null) {
        final List<dynamic> followed = userSnapshot.value as List<dynamic>;
        setState(() {
          followedClubIds =
              followed.where((id) => id != null).cast<String>().toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading followed clubs: $e');
    }
  }

  Future<void> toggleFollow(String clubName) async {
    final isFollowing = followedClubIds.contains(clubName);

    try {
      if (isFollowing) {
        await UserService.unfollowClub(clubName);
        setState(() => followedClubIds.remove(clubName));
      } else {
        await UserService.followClub(clubName);
        setState(() => followedClubIds.add(clubName));
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }
  }

  void fetchClubs() async {
    try {
      final snapshot = await dbRef.get();
      debugPrint('=== FETCH CLUBS DEBUG ===');
      debugPrint('Snapshot exists: ${snapshot.exists}');

      if (snapshot.exists) {
        final data = snapshot.value;
        debugPrint('Data type: ${data.runtimeType}');
        debugPrint('Data is List: ${data is List}');
        debugPrint('Data is Map: ${data is Map}');

        if (data is Map) {
          debugPrint('Map keys: ${data.keys.toList()}');
        }

        final List<Club> loaded = [];

        if (data is List) {
          debugPrint('Data is a List with ${data.length} items');

          for (var i = 0; i < data.length; i++) {
            var item = data[i];
            if (item != null) {
              try {
                final Map<String, dynamic> clubMap =
                    Map<String, dynamic>.from(item);
                final name = clubMap['CLUB:'] ?? '';
                debugPrint('Item $i name: "$name"');

                if (name.toString().isNotEmpty) {
                  loaded.add(Club.fromMap(clubMap));
                  debugPrint('✓ Added club: $name');
                }
              } catch (e) {
                debugPrint('Error processing item $i: $e');
              }
            }
          }
        } else if (data is Map) {
          debugPrint('Data is a Map with ${data.length} entries');
          data.forEach((key, value) {
            debugPrint('Processing key: $key');
            if (value != null && value is Map) {
              try {
                final Map<String, dynamic> clubMap =
                    Map<String, dynamic>.from(value);
                final name = clubMap['CLUB:'] ?? '';
                debugPrint('Club $key name: "$name"');

                if (name.toString().isNotEmpty) {
                  loaded.add(Club.fromMap(clubMap));
                  debugPrint('✓ Added club: $name');
                }
              } catch (e) {
                debugPrint('Error processing $key: $e');
              }
            }
          });
        }

        setState(() {
          clubs = loaded;
          isLoading = false;
        });

        debugPrint('=== FINAL: Successfully loaded ${loaded.length} clubs ===');
      } else {
        debugPrint('Snapshot does not exist!');
        setState(() {
          isLoading = false;
          clubs = [];
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        isLoading = false;
        clubs = [];
      });
    }
  }

  List<Club> get filteredClubs {
    List<Club> filtered = clubs;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((club) {
        return club.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (club.advisor1?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    // Sort alphabetically
    filtered.sort((a, b) => a.name.compareTo(b.name));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (clubs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Discover Clubs'),
          backgroundColor: const Color(0xFF7A1E1E),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No clubs found',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Clubs'),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF7A1E1E),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${filteredClubs.length} clubs',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredClubs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No clubs found',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Try a different search term',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredClubs.length,
                    itemBuilder: (context, index) {
                      final club = filteredClubs[index];
                      return _buildClubCard(club);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(Club club) {
    final isFollowing = followedClubIds.contains(club.name);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubHomePage(club: club),
          ),
        );
        loadFollowedClubs();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7A1E1E),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7A1E1E),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => toggleFollow(club.name),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFollowing ? Icons.favorite : Icons.favorite_border,
                        color: isFollowing ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (club.advisor1 != null && club.advisor1!.isNotEmpty)
                      Text(
                        club.advisor1!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (club.schedule != null && club.schedule!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                club.schedule!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
