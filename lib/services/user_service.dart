import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  static final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref('users');

  // Follow a club
  static Future<void> followClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _usersRef.child('${user.uid}/followedClubs/$clubId').set(true);
  }

  // Unfollow a club
  static Future<void> unfollowClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _usersRef.child('${user.uid}/followedClubs/$clubId').remove();
  }

  // Check if user is following a club
  static Future<bool> isFollowingClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot =
        await _usersRef.child('${user.uid}/followedClubs/$clubId').get();
    return snapshot.exists;
  }
}
