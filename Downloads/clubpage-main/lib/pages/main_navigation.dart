import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import '../services/role_service.dart';
import '../services/message_service.dart';
import 'discovery_page.dart';
import 'calendar_page.dart';
import 'bulletin_board_page.dart';
import 'following_page.dart';
import 'admin_messages_page.dart';
import 'leadership_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  List<Club> _allClubs = [];
  bool _isLoadingClubs = true;
  List<String> _adminClubs = [];
  bool _isLoadingAdminStatus = true;
  int _unreadMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllClubs();
    _checkAdminStatus();
    _listenToUnreadMessages();
  }

  void _listenToUnreadMessages() {
    MessageService.getTotalUnreadCount().listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    try {
      final adminClubs = await RoleService.getAdminClubs();
      if (mounted) {
        setState(() {
          _adminClubs = adminClubs;
          _isLoadingAdminStatus = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      if (mounted) {
        setState(() {
          _isLoadingAdminStatus = false;
        });
      }
    }
  }

  Future<void> _fetchAllClubs() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref().get();

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
          _allClubs = loaded;
          _isLoadingClubs = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching clubs: $e');
      setState(() {
        _isLoadingClubs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingClubs || _isLoadingAdminStatus) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      const DiscoveryPage(),
      const FollowingPage(),
      CalendarPage(clubs: _allClubs),
      BulletinBoardPage(clubs: _allClubs),
      LeadershipPage(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.explore),
        label: 'Discovery',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.favorite),
        label: 'Following',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Calendar',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.announcement),
        label: 'Bulletin',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.star),
        label: 'Leadership',
      ),
    ];

    // Add admin messages page if user is an admin
    if (_adminClubs.isNotEmpty) {
      pages.add(const AdminMessagesPage());
      navItems.add(
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.admin_panel_settings),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadMessageCount > 9 ? '9+' : '$_unreadMessageCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Messages',
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7A1E1E),
        unselectedItemColor: Colors.grey,
        items: navItems,
      ),
    );
  }
}
