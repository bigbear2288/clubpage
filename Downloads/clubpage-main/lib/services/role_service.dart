import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RoleService {
  // Super admin emails — add more here as needed
  static const List<String> _superAdminEmails = [
    'clubs@hopkins.edu',
  ];

  static bool isSuperAdmin() {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    return _superAdminEmails.contains(email);
  }

  // Returns list of club names the current user is head/advisor of
  static Future<List<String>> getAdminClubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userKey = user.email?.replaceAll('.', ',') ?? user.uid;

    // Super admin manages all clubs
    if (isSuperAdmin()) {
      final snapshot = await FirebaseDatabase.instance.ref('clubs').get();
      if (!snapshot.exists || snapshot.value is! Map) return [];
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return data.keys.map((k) => k.toString()).toList();
    }

    final userEmail = user.email?.toLowerCase() ?? '';
    final clubsSnapshot = await FirebaseDatabase.instance.ref('clubs').get();
    if (!clubsSnapshot.exists || clubsSnapshot.value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(clubsSnapshot.value as Map);
    final List<String> adminClubs = [];

    data.forEach((key, value) {
      if (value is! Map) return;
      final club = Map<String, dynamic>.from(value);
      final clubName = key.toString();

      // Check head emails (up to 4)
      final email1 = (club['email_head1'] ?? '').toString().toLowerCase();
      final email2 = (club['email_head2'] ?? '').toString().toLowerCase();
      final email3 = (club['email_head3'] ?? '').toString().toLowerCase();
      final email4 = (club['email_head4'] ?? '').toString().toLowerCase();

      if (email1 == userEmail ||
          email2 == userEmail ||
          email3 == userEmail ||
          email4 == userEmail) {
        adminClubs.add(clubName);
        return;
      }

      // Check advisor emails derived from name "John Smith" -> jsmith@hopkins.edu
      for (var advisorKey in ['advisor1', 'advisor2']) {
        final name = (club[advisorKey] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final parts = name.split(' ');
        if (parts.length >= 2) {
          final derived =
              '${parts[0][0].toLowerCase()}${parts.last.toLowerCase()}@hopkins.edu';
          if (derived == userEmail) {
            adminClubs.add(clubName);
            break;
          }
        }
      }
    });

    // Save to Firebase using consistent user key
    await FirebaseDatabase.instance
        .ref('users/$userKey/adminClubs')
        .set(adminClubs);

    return adminClubs;
  }

  // Get follower count for a specific club
  static Future<int> getFollowerCount(String clubName) async {
    final usersSnapshot = await FirebaseDatabase.instance.ref('users').get();
    if (!usersSnapshot.exists || usersSnapshot.value is! Map) return 0;

    final users = Map<dynamic, dynamic>.from(usersSnapshot.value as Map);
    int count = 0;

    users.forEach((uid, userData) {
      if (userData is! Map) return;
      final followedClubs = userData['followedClubs'];
      if (followedClubs is Map && followedClubs.containsKey(clubName)) {
        count++;
      }
    });

    return count;
  }

  // Get all followers as display names (falls back to email, then uid)
  static Future<List<String>> getFollowers(String clubName) async {
    final usersSnapshot = await FirebaseDatabase.instance.ref('users').get();
    if (!usersSnapshot.exists || usersSnapshot.value is! Map) return [];

    final users = Map<dynamic, dynamic>.from(usersSnapshot.value as Map);
    final List<String> followers = [];

    users.forEach((uid, userData) {
      if (userData is! Map) return;
      final followedClubs = userData['followedClubs'];
      if (followedClubs is Map && followedClubs.containsKey(clubName)) {
        final displayName = userData['displayName']?.toString() ?? '';
        final email = userData['email']?.toString() ?? '';
        // Use display name if available, otherwise email, otherwise uid
        followers.add(displayName.isNotEmpty
            ? displayName
            : email.isNotEmpty
                ? email
                : uid.toString());
      }
    });

    followers.sort();
    return followers;
  }
}
