import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../services/user_service.dart';
import 'club_home_page.dart';
import 'login_page.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  final dbRef = FirebaseDatabase.instance.ref('clubs');

  List<Club> allClubs = [];
  Set<String> followedClubIds = {};
  Set<String> myClubIds = {};
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchClubs();
    _listenToFollowedClubs();
    _listenToMyClubs();
  }

  void _listenToMyClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    FirebaseDatabase.instance
        .ref('users/$userKey/myClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      setState(() {
        if (data is Map) {
          myClubIds = data.keys.cast<String>().toSet();
        } else {
          myClubIds = {};
        }
      });
    });
  }

  void _listenToFollowedClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref('users/${user.uid}/followedClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      setState(() {
        if (data is Map) {
          followedClubIds = data.keys.cast<String>().toSet();
        } else {
          followedClubIds = {};
        }
      });
    }, onError: (e) {
      debugPrint('Error listening to followed clubs: $e');
    });
  }

  Future<void> toggleFollow(String clubName) async {
    final wasFollowing = followedClubIds.contains(clubName);
    try {
      if (wasFollowing) {
        await UserService.unfollowClub(clubName);
      } else {
        await UserService.followClub(clubName);
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
          allClubs = [];
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
        allClubs = loaded;
        isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error fetching clubs: $e');
      setState(() => isLoading = false);
    });
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

  List<Club> get myClubs {
    return filteredClubs
        .where((club) => myClubIds.contains(club.name))
        .toList();
  }

  List<Club> get otherClubs {
    return filteredClubs
        .where((club) => !myClubIds.contains(club.name))
        .toList();
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                        Icon(Icons.favorite_border,
                            size: MediaQuery.of(context).size.width < 600
                                ? 64
                                : 80,
                            color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No favorited clubs yet',
                            style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 18
                                        : 22,
                                color: Colors.grey[600])),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Go to Discovery to find clubs to follow',
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
                : _buildClubsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsList() {
    if (filteredClubs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: MediaQuery.of(context).size.width < 600 ? 64 : 80,
                color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No clubs found',
                style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 22,
                    color: Colors.grey[600])),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Try a different search term',
                  style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 14 : 16,
                      color: Colors.grey[500])),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 600 ? 16 : 24,
          ),
          children: [
            if (myClubs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A1E1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'My Clubs',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth < 600
                      ? 2
                      : (constraints.maxWidth < 900 ? 3 : 4),
                  childAspectRatio: 0.85,
                  crossAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
                  mainAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
                ),
                itemCount: myClubs.length,
                itemBuilder: (context, index) {
                  final club = myClubs[index];
                  return _buildClubCard(club, constraints.maxWidth);
                },
              ),
              const SizedBox(height: 24),
            ],
            if (otherClubs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(
                      'Following',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth < 600
                      ? 2
                      : (constraints.maxWidth < 900 ? 3 : 4),
                  childAspectRatio: 0.85,
                  crossAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
                  mainAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
                ),
                itemCount: otherClubs.length,
                itemBuilder: (context, index) {
                  final club = otherClubs[index];
                  return _buildClubCard(club, constraints.maxWidth);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClubHomePage(club: club)),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    color: club.clubColor,
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
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (club.head1?.isNotEmpty ?? false) ...[
                          Text('Club Head',
                              style: TextStyle(
                                  fontSize: advisorLabelFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: club.clubColor,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 3),
                          Text(club.head1!,
                              style: TextStyle(
                                  fontSize: advisorNameFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF424242)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
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
                        if ((club.head1?.isNotEmpty ?? false) &&
                            (club.advisor1?.isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1, color: Colors.grey[300]),
                          ),
                        if (club.advisor1?.isNotEmpty ?? false) ...[
                          Text('Advisor',
                              style: TextStyle(
                                  fontSize: advisorLabelFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 3),
                          Text(club.advisor1!,
                              style: TextStyle(
                                  fontSize: advisorNameFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF424242)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
