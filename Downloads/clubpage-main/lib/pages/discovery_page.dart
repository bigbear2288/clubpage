import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import 'club_home_page.dart';
import 'club_message_page.dart';

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
  Map<String, String> latestAnnouncements = {};
  bool isSuperAdmin = false;
  bool hasShownEasterEgg = false;

  Set<String> selectedCategories = {};

  Set<String> get allCategories {
    final cats = <String>{};
    for (final club in clubs) {
      final cat = (club.category ?? '').trim();
      if (cat.isNotEmpty) cats.add(cat);
    }
    return cats;
  }

  @override
  void initState() {
    super.initState();
    isSuperAdmin = RoleService.isSuperAdmin();
    fetchClubs();
    listenToFollowedClubs();
    listenToAnnouncements();
  }

  void listenToFollowedClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userKey = (user.email ?? user.uid).replaceAll('.', ',');
    FirebaseDatabase.instance
        .ref('users/$userKey/followedClubs')
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

      if (!hasShownEasterEgg && followedClubIds.length >= 5) {
        hasShownEasterEgg = true;
        _showEasterEgg();
      }
    });
  }

  void _showEasterEgg() {
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🐱',
                    style: TextStyle(fontSize: 80),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Congratulations!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You followed 5 clubs!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A1E1E),
                    ),
                    child: const Text(
                      'Yay! 🎉',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void listenToAnnouncements() {
    announcementsRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      if (data == null) {
        setState(() => latestAnnouncements = {});
        return;
      }

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
            message.isEmpty) {
          return;
        }

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
    });
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

  Future<void> toggleFollow(String clubName) async {
    final isFollowing = followedClubIds.contains(clubName);

    setState(() {
      if (isFollowing) {
        followedClubIds.remove(clubName);
      } else {
        followedClubIds.add(clubName);
      }
    });

    try {
      if (isFollowing) {
        await UserService.unfollowClub(clubName);
      } else {
        await UserService.followClub(clubName);
        final club = clubs.firstWhere(
          (c) => c.name == clubName,
          orElse: () => Club.fromMap({'name': clubName}),
        );
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ClubMessagePage(club: club)),
          );
        }
      }
    } catch (e) {
      setState(() {
        if (isFollowing) {
          followedClubIds.add(clubName);
        } else {
          followedClubIds.remove(clubName);
        }
      });
      debugPrint('Error toggling follow: $e');
    }
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
    if (selectedCategories.isNotEmpty) {
      filtered = filtered.where((club) {
        return selectedCategories.contains((club.category ?? '').trim());
      }).toList();
    }
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  void _showAddClubDialog() {
    final nameController = TextEditingController();
    final advisor1Controller = TextEditingController();
    final advisor2Controller = TextEditingController();
    final head1Controller = TextEditingController();
    final head2Controller = TextEditingController();
    final emailHead1Controller = TextEditingController();
    final emailHead2Controller = TextEditingController();
    final roomController = TextEditingController();
    final scheduleController = TextEditingController();
    final timeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Club'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, 'Club Name *'),
              _dialogField(advisor1Controller, 'Advisor 1'),
              _dialogField(advisor2Controller, 'Advisor 2'),
              _dialogField(head1Controller, 'Club Head 1'),
              _dialogField(emailHead1Controller, 'Head 1 Email'),
              _dialogField(head2Controller, 'Club Head 2'),
              _dialogField(emailHead2Controller, 'Head 2 Email'),
              _dialogField(roomController, 'Room'),
              _dialogField(scheduleController, 'Schedule'),
              _dialogField(timeController, 'Time'),
              _dialogField(descriptionController, 'Description', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A1E1E)),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await FirebaseDatabase.instance.ref('clubs/$name').set({
                'advisor1': advisor1Controller.text.trim(),
                'advisor2': advisor2Controller.text.trim(),
                'head1': head1Controller.text.trim(),
                'head2': head2Controller.text.trim(),
                'email_head1': emailHead1Controller.text.trim(),
                'email_head2': emailHead2Controller.text.trim(),
                'room': roomController.text.trim(),
                'schedule': scheduleController.text.trim(),
                'time': timeController.text.trim(),
                'description': descriptionController.text.trim(),
              });
              Navigator.pop(context);
            },
            child:
                const Text('Add Club', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  void _confirmDeleteClub(Club club) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Club'),
        content: Text(
            'Are you sure you want to delete "${club.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseDatabase.instance
                  .ref('clubs/${club.name}')
                  .remove();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter by Category',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setSheetState(() => selectedCategories.clear());
                          setState(() {});
                        },
                        child: const Text('Clear all',
                            style: TextStyle(color: Color(0xFF7A1E1E))),
                      ),
                    ],
                  ),
                  const Divider(),
                  ...allCategories.map((cat) {
                    final isSelected = selectedCategories.contains(cat);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(cat),
                      activeColor: const Color(0xFF7A1E1E),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setSheetState(() {
                          if (val == true) {
                            selectedCategories.add(cat);
                          } else {
                            selectedCategories.remove(cat);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Discover Clubs', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white),
              tooltip: 'Add Club',
              onPressed: _showAddClubDialog,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: clubs.isEmpty
          ? Center(
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
            )
          : Column(
              children: [
                Container(
                  color: const Color(0xFF7A1E1E),
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.of(context).size.width < 600 ? 16 : 24,
                    0,
                    MediaQuery.of(context).size.width < 600 ? 8 : 12,
                    MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search clubs...',
                            hintStyle: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 14
                                        : 16),
                            prefixIcon: Icon(Icons.search,
                                size: MediaQuery.of(context).size.width < 600
                                    ? 20
                                    : 24),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical:
                                    MediaQuery.of(context).size.width < 600
                                        ? 12
                                        : 16),
                          ),
                          style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 600
                                  ? 14
                                  : 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune,
                                color: Colors.white, size: 28),
                            tooltip: 'Filter by category',
                            onPressed: _showFilterSheet,
                          ),
                          if (selectedCategories.isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${selectedCategories.length}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7A1E1E),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 18
                                              : 22,
                                      color: Colors.grey[600])),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('Try a different search term',
                                    style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    600
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
                                  horizontal:
                                      constraints.maxWidth < 600 ? 16 : 24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.75,
                                crossAxisSpacing:
                                    constraints.maxWidth < 600 ? 12 : 16,
                                mainAxisSpacing:
                                    constraints.maxWidth < 600 ? 12 : 16,
                              ),
                              itemCount: filteredClubs.length,
                              itemBuilder: (context, index) {
                                final club = filteredClubs[index];
                                return _buildClubCard(
                                    club, constraints.maxWidth);
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
                                letterSpacing: 0.5,
                              )),
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
                                letterSpacing: 0.5,
                              )),
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
            if (isSuperAdmin)
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  onTap: () => _confirmDeleteClub(club),
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
                    child: Icon(Icons.delete,
                        color: Colors.red[400], size: iconSize),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
