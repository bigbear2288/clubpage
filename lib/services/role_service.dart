import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RoleService {
  static Future<List<String>> getAdminClubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userEmail = user.email?.toLowerCase() ?? '';
    final clubsSnapshot = await FirebaseDatabase.instance.ref('clubs').get();

    if (!clubsSnapshot.exists || clubsSnapshot.value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(clubsSnapshot.value as Map);
    final List<String> adminClubs = [];

    data.forEach((key, value) {
      if (value is! Map) return;
      final club = Map<String, dynamic>.from(value);
      final clubName = key.toString();

      // Check all four head emails
      final email1 = (club['email_head1'] ?? '').toString().toLowerCase();
      final email2 = (club['email_head2'] ?? '').toString().toLowerCase();
      final email3 =
          (club['email_head3'] ?? '').toString().toLowerCase(); // ADD
      final email4 =
          (club['email_head4'] ?? '').toString().toLowerCase(); // ADD

      if (email1 == userEmail ||
          email2 == userEmail ||
          email3 == userEmail || // ADD
          email4 == userEmail) {
        // ADD
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

    await FirebaseDatabase.instance
        .ref('users/${user.uid}/adminClubs')
        .set(adminClubs);

    return adminClubs;
  }
}
