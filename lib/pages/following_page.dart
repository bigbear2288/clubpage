import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../services/user_service.dart';
import 'club_home_page.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  List<Club> allClubs = [];
  Set<String> followedClubIds = {};
  bool isLoading = true;
  String searchQuery = '';

  StreamSubscription? _followedClubsSubscription;

  @override
  void initState() {
    super.initState();
    fetchClubs();
    _listenToFollowedClubs();
  }

  @override
  void dispose() {
    _followedClubsSubscription?.cancel();
    super.dispose();
  }

  // Use a real-time stream so changes from DiscoveryPage reflect instantly
  void _listenToFollowedClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _followedClubsSubscription = FirebaseDatabase.instance
        .ref('users/${user.uid}/followedClubs')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final List<dynamic> followed = event.snapshot.value as List<dynamic>;
        setState(() {
          followedClubIds =
              followed.where((id) => id != null).cast<String>().toSet();
        });
      } else {
        setState(() {
          followedClubIds = {};
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to followed clubs: $e');
    });
  }

  Future<void> toggleFollow(String clubName) async {
    final isFollowing = followedClubIds.contains(clubName);

    try {
      if (isFollowing) {
        await UserService.unfollowClub(clubName);
        // No need to setState — the stream listener will update automatically
      } else {
        await UserService.followClub(clubName);
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }
  }

  void fetchClubs() async {
    try {
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final data = snapshot.value;
        final List<Club> loaded = [];

        if (data is List) {
          for (var i = 0; i < data.length; i++) {
            var item = data[i];
            if (item != null) {
              try {
                final Map<String, dynamic> clubMap =
                    Map<String, dynamic>.from(item);
                final name = clubMap['CLUB:'] ?? '';
                if (name.toString().isNotEmpty) {
                  loaded.add(Club.fromMap(clubMap));
                }
              } catch (e) {
                debugPrint('Error processing item $i: $e');
              }
            }
          }
        } else if (data is Map) {
          data.forEach((key, value) {
            if (value != null && value is Map) {
              try {
                final Map<String, dynamic> clubMap =
                    Map<String, dynamic>.from(value);
                final name = clubMap['CLUB:'] ?? '';
                if (name.toString().isNotEmpty) {
                  loaded.add(Club.fromMap(clubMap));
                }
              } catch (e) {
                debugPrint('Error processing $key: $e');
              }
            }
          });
        }

        setState(() {
          allClubs = loaded;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          allClubs = [];
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        isLoading = false;
        allClubs = [];
      });
    }
  }

  List<Club> get filteredClubs {
    List<Club> filtered =
        allClubs.where((club) => followedClubIds.contains(club.name)).toList();

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((club) {
        return club.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (club.advisor1?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Following',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar — matches DiscoveryPage exactly
          if (followedClubIds.isNotEmpty)
            Container(
              color: const Color(0xFF7A1E1E),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width < 600 ? 16 : 24,
                0,
                MediaQuery.of(context).size.width < 600 ? 16 : 24,
                MediaQuery.of(context).size.width < 600 ? 16 : 20,
              ),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search your clubs...',
                  hintStyle: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  ),
                ),
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                ),
              ),
            ),

          // Club count — matches DiscoveryPage exactly
          if (followedClubIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 16 : 20,
              ),
              child: Row(
                children: [
                  Text(
                    '${filteredClubs.length} clubs',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 14 : 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: followedClubIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size:
                              MediaQuery.of(context).size.width < 600 ? 64 : 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No favorited clubs yet',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 18
                                : 22,
                            color: Colors.grey[600],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Go to Discovery to find clubs to follow',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 600
                                  ? 14
                                  : 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredClubs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: MediaQuery.of(context).size.width < 600
                                  ? 64
                                  : 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No clubs found',
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 18
                                        : 22,
                                color: Colors.grey[600],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Try a different search term',
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 14
                                          : 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount;
                          if (constraints.maxWidth < 600) {
                            crossAxisCount = 2;
                          } else if (constraints.maxWidth < 900) {
                            crossAxisCount = 3;
                          } else {
                            crossAxisCount = 4;
                          }

                          return GridView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth < 600 ? 16 : 24,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.85,
                              crossAxisSpacing:
                                  constraints.maxWidth < 600 ? 12 : 16,
                              mainAxisSpacing:
                                  constraints.maxWidth < 600 ? 12 : 16,
                            ),
                            itemCount: filteredClubs.length,
                            itemBuilder: (context, index) {
                              final club = filteredClubs[index];
                              return _buildClubCard(club, constraints.maxWidth);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Identical to DiscoveryPage._buildClubCard
  Widget _buildClubCard(Club club, double screenWidth) {
    final isFollowing = followedClubIds.contains(club.name);

    double clubNameFontSize =
        screenWidth < 600 ? 12 : (screenWidth < 900 ? 13 : 14);
    double advisorLabelFontSize =
        screenWidth < 600 ? 9 : (screenWidth < 900 ? 10 : 11);
    double advisorNameFontSize =
        screenWidth < 600 ? 11 : (screenWidth < 900 ? 12 : 13);
    double advisor2FontSize =
        screenWidth < 600 ? 10 : (screenWidth < 900 ? 11 : 12);
    double iconSize = screenWidth < 600 ? 16 : (screenWidth < 900 ? 18 : 20);
    double cardPadding = screenWidth < 600 ? 12 : (screenWidth < 900 ? 14 : 16);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubHomePage(club: club),
          ),
        );
        // No need to manually reload — stream handles it
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                // Maroon header (1/4)
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
                          style: TextStyle(
                            fontSize: clubNameFontSize,
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
                // White body (3/4)
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (club.advisor1?.isNotEmpty ?? false) ...[
                          Text(
                            'Advisor',
                            style: TextStyle(
                              fontSize: advisorLabelFontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            club.advisor1!,
                            style: TextStyle(
                              fontSize: advisorNameFontSize,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF424242),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (club.advisor2?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 6),
                          Text(
                            club.advisor2!,
                            style: TextStyle(
                              fontSize: advisor2FontSize,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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
                    size: iconSize,
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
