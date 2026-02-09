import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import 'discovery_page.dart';
import 'calendar_page.dart';
import 'bulletin_board_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  List<Club> _allClubs = [];
  bool _isLoadingClubs = true;

  @override
  void initState() {
    super.initState();
    _fetchAllClubs();
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
    if (_isLoadingClubs) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      const DiscoveryPage(),
      const FollowingPage(),
      CalendarPage(clubs: _allClubs),
      BulletinBoardPage(clubs: _allClubs),
    ];

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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discovery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Following',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Bulletin',
          ),
        ],
      ),
    );
  }
}

// Following Page - shows only followed clubs
class FollowingPage extends StatelessWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // This will be the same as DiscoveryPage but with filter always set to Following
    return const DiscoveryPage();
  }
}
