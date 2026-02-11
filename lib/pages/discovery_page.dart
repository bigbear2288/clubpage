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
          title: const Text(
            'Discover Clubs',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF7A1E1E),
          iconTheme: const IconThemeData(color: Colors.white),
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
        title: const Text(
          'Discover Clubs',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                      crossAxisCount: 4, // 4 per row
                      childAspectRatio: 1, // Square
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
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Main card content
            Column(
              children: [
                // Maroon header section (1/4 of card)
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7A1E1E),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          club.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                // White background section (3/4 of card)
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (club.advisor1?.isNotEmpty ?? false) ...[
                          const Text(
                            'Advisor',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            club.advisor1!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF424242),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (club.advisor2?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 6),
                          Text(
                            club.advisor2!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Heart icon
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => toggleFollow(club.name),
                child: Container(
                  padding: const EdgeInsets.all(4),
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
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}