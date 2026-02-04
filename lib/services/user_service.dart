import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  static final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  
  // Follow a club
  static Future<void> followClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final followedClubsRef = _usersRef.child('${user.uid}/followedClubs');
    final snapshot = await followedClubsRef.get();
    
    List<String> followedClubs = [];
    if (snapshot.exists && snapshot.value != null) {
      followedClubs = List<String>.from(snapshot.value as List);
    }
    
    if (!followedClubs.contains(clubId)) {
      followedClubs.add(clubId);
      await followedClubsRef.set(followedClubs);
    }
  }
  
  // Unfollow a club
  static Future<void> unfollowClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final followedClubsRef = _usersRef.child('${user.uid}/followedClubs');
    final snapshot = await followedClubsRef.get();
    
    if (snapshot.exists && snapshot.value != null) {
      List<String> followedClubs = List<String>.from(snapshot.value as List);
      followedClubs.remove(clubId);
      await followedClubsRef.set(followedClubs);
    }
  }
  
  // Check if user is following a club
  static Future<bool> isFollowingClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final followedClubsRef = _usersRef.child('${user.uid}/followedClubs');
    final snapshot = await followedClubsRef.get();
    
    if (snapshot.exists && snapshot.value != null) {
      List<String> followedClubs = List<String>.from(snapshot.value as List);
      return followedClubs.contains(clubId);
    }
    return false;
  }
}
