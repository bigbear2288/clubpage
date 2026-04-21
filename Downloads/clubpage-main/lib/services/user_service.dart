import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  static final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref('users');

  static String _getUserKey() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email?.replaceAll('.', ',') ?? user?.uid ?? '';
  }

  // Follow a club
  static Future<void> followClub(String clubId) async {
    final userKey = _getUserKey();
    if (userKey.isEmpty) return;

    await _usersRef.child('$userKey/followedClubs/$clubId').set(true);
  }

  // Unfollow a club
  static Future<void> unfollowClub(String clubId) async {
    final userKey = _getUserKey();
    if (userKey.isEmpty) return;

    await _usersRef.child('$userKey/followedClubs/$clubId').remove();
  }

  // Check if user is following a club
  static Future<bool> isFollowingClub(String clubId) async {
    final userKey = _getUserKey();
    if (userKey.isEmpty) return false;

    final snapshot =
        await _usersRef.child('$userKey/followedClubs/$clubId').get();
    return snapshot.exists;
  }

  // Request to join a club
  static Future<void> requestToJoin(String clubName) async {
    final userKey = _getUserKey();
    if (userKey.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final requestRef = _usersRef.child('$userKey/joinRequests/$clubName');

    await requestRef.set({
      'status': 'pending',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'userName': user?.displayName ?? user?.email ?? 'User',
      'userEmail': user?.email ?? '',
    });

    await FirebaseDatabase.instance
        .ref('joinRequests/$clubName/${user?.uid}')
        .set({
      'status': 'pending',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'userName': user?.displayName ?? user?.email ?? 'User',
      'userEmail': user?.email ?? '',
    });
  }

  // Cancel join request
  static Future<void> cancelJoinRequest(String clubName) async {
    final userKey = _getUserKey();
    if (userKey.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    await _usersRef.child('$userKey/joinRequests/$clubName').remove();
    await FirebaseDatabase.instance
        .ref('joinRequests/$clubName/${user?.uid}')
        .remove();
  }

  // Check join request status
  static Future<String?> getJoinRequestStatus(String clubName) async {
    final userKey = _getUserKey();
    if (userKey.isEmpty) return null;

    final snapshot =
        await _usersRef.child('$userKey/joinRequests/$clubName/status').get();
    return snapshot.value as String?;
  }
}
