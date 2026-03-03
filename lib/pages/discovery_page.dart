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
  final dbRef = FirebaseDatabase.instance.ref('clubs');
  final announcementsRef = FirebaseDatabase.instance.ref('announcements');

  List<Club> clubs = [];
  Set<String> followedClubIds = {};
  bool isLoading = true;
  String searchQuery = '';

  // clubName -> latest announcement message
  Map<String, String> latestAnnouncements = {};

  @override
  void initState() {
    super.initState();
    fetchClubs();
    loadFollowedClubs();
    _subscribeToAnnouncements();
  }

  /// Single listener on the root `announcements` node.
  /// Any time any announcement is added/changed, we rebuild the map.
  void _subscribeToAnnouncements() {
    announcementsRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      if (data == null) {
        setState(() => latestAnnouncements = {});
        return;
      }

      // Map: clubName -> {timestamp, message}
      final Map<String, Map<String, dynamic>> best = {};

      void process(dynamic value) {
        if (value is! Map) return;
        final clubName = value['clubName']?.toString();
        final message = value['message']?.toString();
        final ts = value['timestamp'];
        final tsInt = ts is int ? ts : int.tryParse(ts?.toString() ?? '') ?? 0;

        if (clubName == null ||
            clubName.isEmpty ||
            message == null ||
            message.isEmpty) return;

        if (!best.containsKey(clubName) ||
            tsInt > (best[clubName]!['ts'] as int)) {
          best[clubName] = {'ts': tsInt, 'message': message};
        }
      }

      if (data is Map) {
        data.forEach((_, value) => process(value));
      } else if (data is List) {
        for (final value in data) {
          process(value);
        }
      }

      setState(() {
        latestAnnouncements =
            best.map((k, v) => MapEntry(k, v['message'] as String));
      });
    }, onError: (e) {
      debugPrint('Error listening to announcements: $e');
    });
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

  void fetchClubs() {
    dbRef.onValue.listen((event) {
      if (!mounted) return;

      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          clubs = [];
          isLoading = false;
        });
        return;
      }

      final data = snapshot.value;
      final List<Club> loaded = [];

      try {
        if (data is List) {
          for (var i = 0; i < data.length; i++) {
            final item = data[i];
            if (item != null) {
              final Map<String, dynamic> clubMap =
                  Map<String, dynamic>.from(item);
              final name = clubMap['CLUB:'] ?? '';
              if (name.toString().isNotEmpty) loaded.add(Club.fromMap(clubMap));
            }
          }
        } else if (data is Map) {
          data.forEach((key, value) {
            if (value != null && value is Map) {
              final Map<String, dynamic> clubMap =
                  Map<String, dynamic>.from(value);
              clubMap['name'] = key.toString();
              if (key.toString().isNotEmpty) loaded.add(Club.fromMap(clubMap));
            }
          });
        }
      } catch (e) {
        debugPrint('Error parsing clubs: $e');
      }

      setState(() {
        clubs = loaded;
        isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error fetching clubs: $e');
      setState(() => isLoading = false);
    });
  }

  List<Club> get filteredClubs {
    List<Club> filtered = clubs;
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (clubs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Discover Clubs',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF7A1E1E),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined,
                  size: MediaQuery.of(context).size.width < 600 ? 64 : 80,
                  color: Colors.grey),
              const SizedBox(height: 16),
              Text('No clubs found',
                  style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 18 : 22,
                      color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Discover Clubs', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
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
                hintText: 'Search clubs...',
                hintStyle: TextStyle(
                    fontSize:
                        MediaQuery.of(context).size.width < 600 ? 14 : 16),
                prefixIcon: Icon(Icons.search,
                    size: MediaQuery.of(context).size.width < 600 ? 20 : 24),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                    vertical:
                        MediaQuery.of(context).size.width < 600 ? 12 : 16),
              ),
              style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 16 : 20),
            child: Row(
              children: [
                Text(
                  '${filteredClubs.length} clubs',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
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
                            size: MediaQuery.of(context).size.width < 600
                                ? 64
                                : 80,
                            color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No clubs found',
                            style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 18
                                        : 22,
                                color: Colors.grey[600])),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Try a different search term',
                              style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 14
                                          : 16,
                                  color: Colors.grey[500])),
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
                            horizontal: constraints.maxWidth < 600 ? 16 : 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.75,
                          crossAxisSpacing:
                              constraints.maxWidth < 600 ? 12 : 16,
                          mainAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
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

  Widget _buildClubCard(Club club, double screenWidth) {
    final isFollowing = followedClubIds.contains(club.name);
    final announcement = latestAnnouncements[club.name];

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
    double announcementFontSize =
        screenWidth < 600 ? 9 : (screenWidth < 900 ? 10 : 11);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClubHomePage(club: club)),
        );
        loadFollowedClubs();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                // Maroon header
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF7A1E1E),
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
                // White body
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Club heads
                        if (club.head1?.isNotEmpty ?? false) ...[
                          Text(
                            'Club Head',
                            style: TextStyle(
                              fontSize: advisorLabelFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7A1E1E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            club.head1!,
                            style: TextStyle(
                              fontSize: advisorNameFontSize,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF424242),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (club.head2?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(club.head2!,
                              style: TextStyle(
                                  fontSize: advisor2FontSize,
                                  color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ],
                        if (club.head3?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(club.head3!,
                              style: TextStyle(
                                  fontSize: advisor2FontSize,
                                  color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ],
                        if (club.head4?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(club.head4!,
                              style: TextStyle(
                                  fontSize: advisor2FontSize,
                                  color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ],
                        // Divider before advisor
                        if ((club.head1?.isNotEmpty ?? false) &&
                            (club.advisor1?.isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1, color: Colors.grey[300]),
                          ),
                        // Advisors
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
                          const SizedBox(height: 3),
                          Text(
                            club.advisor1!,
                            style: TextStyle(
                              fontSize: advisorNameFontSize,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF424242),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (club.advisor2?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(club.advisor2!,
                              style: TextStyle(
                                  fontSize: advisor2FontSize,
                                  color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ],
                        // Latest announcement
                        if (announcement != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Divider(height: 1, color: Colors.grey[300]),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.campaign,
                                  size: announcementFontSize + 2,
                                  color: const Color(0xFF7A1E1E)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  announcement,
                                  style: TextStyle(
                                    fontSize: announcementFontSize,
                                    color: Colors.grey[800],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                          color: Colors.black.withOpacity(0.1), blurRadius: 4)
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
