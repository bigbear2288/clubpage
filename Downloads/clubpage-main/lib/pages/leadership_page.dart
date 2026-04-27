import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import 'club_home_page.dart';

class LeadershipPage extends StatefulWidget {
  const LeadershipPage({super.key});

  @override
  State<LeadershipPage> createState() => _LeadershipPageState();
}

class _LeadershipPageState extends State<LeadershipPage> {
  List<Club> leadershipClubs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeadershipClubs();
  }

  Future<void> _fetchLeadershipClubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    final userEmail = (user.email ?? '').toLowerCase().trim();

    FirebaseDatabase.instance.ref('clubs').onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      final List<Club> loaded = [];

      if (data is Map) {
        data.forEach((key, value) {
          if (value != null && value is Map) {
            final clubMap = Map<String, dynamic>.from(value);
            clubMap['name'] = key.toString();
            final club = Club.fromMap(clubMap);

            final emails = [
              (club.emailHead1 ?? '').toLowerCase().trim(),
              (club.emailHead2 ?? '').toLowerCase().trim(),
            ];

            if (emails.contains(userEmail)) {
              loaded.add(club);
            }
          }
        });
      }

      loaded.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        leadershipClubs = loaded;
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leadership Roles',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : leadershipClubs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border,
                          size: 72, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No leadership roles found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clubs where you\'re listed as a head\nwill appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: leadershipClubs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final club = leadershipClubs[index];
                    return _buildLeadershipCard(club);
                  },
                ),
    );
  }

  Widget _buildLeadershipCard(Club club) {
    // Determine this user's role label
    final userEmail =
        (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    String roleLabel = 'Club Head';
    if ((club.emailHead1 ?? '').toLowerCase().trim() == userEmail &&
        club.head1?.isNotEmpty == true) {
      roleLabel = club.head1!;
    } else if ((club.emailHead2 ?? '').toLowerCase().trim() == userEmail &&
        club.head2?.isNotEmpty == true) {
      roleLabel = club.head2!;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubHomePage(club: club)),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Colored sidebar
            Container(
              width: 8,
              height: 80,
              color: const Color(0xFF7A1E1E),
            ),
            // Content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (club.advisor1?.isNotEmpty ?? false)
                            Text(
                              'Advisor: ${club.advisor1}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (club.schedule?.isNotEmpty ?? false)
                            Text(
                              club.schedule!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A1E1E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF7A1E1E).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              size: 12, color: Color(0xFF7A1E1E)),
                          const SizedBox(width: 4),
                          Text(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7A1E1E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
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
