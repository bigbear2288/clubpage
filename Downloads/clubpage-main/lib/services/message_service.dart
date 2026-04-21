import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MessageReaction {
  final String emoji;
  final String userId;
  final String userName;

  MessageReaction({
    required this.emoji,
    required this.userId,
    required this.userName,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> data) {
    return MessageReaction(
      emoji: data['emoji'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'userId': userId,
      'userName': userName,
    };
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String clubName;
  final String text;
  final int timestamp;
  final List<String> toHeads;
  final bool readByClubHeads;
  final String? replyText;
  final int? replyTimestamp;
  final bool isLeader; // true if sender is a head or advisor
  final Map<String, List<MessageReaction>> reactions;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.clubName,
    required this.text,
    required this.timestamp,
    required this.toHeads,
    required this.readByClubHeads,
    this.replyText,
    this.replyTimestamp,
    this.isLeader = false,
    Map<String, List<MessageReaction>>? reactions,
  }) : reactions = reactions ?? {};

  factory Message.fromMap(String id, Map<String, dynamic> data) {
    final reactionsData = data['reactions'] as Map<String, dynamic>?;
    Map<String, List<MessageReaction>> reactions = {};

    if (reactionsData != null) {
      reactionsData.forEach((emoji, reactionList) {
        if (reactionList is List) {
          reactions[emoji] = reactionList
              .map((r) => MessageReaction.fromMap(Map<String, dynamic>.from(r)))
              .toList();
        }
      });
    }

    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      clubName: data['clubName'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? 0,
      toHeads: List<String>.from(data['toHeads'] ?? []),
      readByClubHeads: data['readByClubHeads'] ?? false,
      replyText: data['replyText'],
      replyTimestamp: data['replyTimestamp'],
      isLeader: data['isLeader'] ?? false,
      reactions: reactions,
    );
  }

  Map<String, dynamic> toMap() {
    final reactionsMap = <String, dynamic>{};
    reactions.forEach((emoji, reactionList) {
      reactionsMap[emoji] = reactionList.map((r) => r.toMap()).toList();
    });

    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'clubName': clubName,
      'text': text,
      'timestamp': timestamp,
      'toHeads': toHeads,
      'readByClubHeads': readByClubHeads,
      'replyText': replyText,
      'replyTimestamp': replyTimestamp,
      'isLeader': isLeader,
      'reactions': reactionsMap,
    };
  }
}

class MessageService {
  static final DatabaseReference _messagesRef =
      FirebaseDatabase.instance.ref('clubMessages');

  static String _safeClubKey(String clubName) {
    return clubName
        .replaceAll(RegExp(r'[.#\$\[\]/]'), '_')
        .replaceAll(' ', '_')
        .toLowerCase();
  }

  // Send a message to club heads (legacy 1:1 style)
  static Future<void> sendMessageToClubHeads({
    required String clubName,
    required String text,
    required List<String> toHeads,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final clubKey = _safeClubKey(clubName);
    final messageRef = _messagesRef.child(clubKey).child('messages').push();

    final message = Message(
      id: messageRef.key!,
      senderId: user.uid,
      senderName: user.displayName ?? 'Student',
      senderEmail: user.email ?? '',
      clubName: clubName,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      toHeads: toHeads,
      readByClubHeads: false,
      isLeader: false,
    );

    await messageRef.set(message.toMap());
  }

  // Send a group chat message (any follower or leader)
  static Future<void> sendGroupMessage({
    required String clubName,
    required String text,
    required bool isLeader,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final clubKey = _safeClubKey(clubName);
    final messageRef = _messagesRef.child(clubKey).child('messages').push();

    final message = Message(
      id: messageRef.key!,
      senderId: user.uid,
      senderName: user.displayName ?? user.email ?? 'Member',
      senderEmail: user.email ?? '',
      clubName: clubName,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      toHeads: [],
      readByClubHeads: isLeader,
      isLeader: isLeader,
    );

    await messageRef.set(message.toMap());
  }

  // Get messages for a specific club, oldest first (for group chat)
  static Stream<List<Message>> getGroupMessages(String clubName) {
    final clubKey = _safeClubKey(clubName);
    final messagesRef = _messagesRef.child(clubKey).child('messages');

    return messagesRef.onValue.map((event) {
      if (!event.snapshot.exists) return [];

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final messages = <Message>[];

      data.forEach((key, value) {
        if (value is Map) {
          messages.add(Message.fromMap(key, Map<String, dynamic>.from(value)));
        }
      });

      // Sort oldest first for chat display
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // Get messages for a specific club (for admin inbox — newest first)
  static Stream<List<Message>> getMessagesForClub(String clubName) {
    final clubKey = _safeClubKey(clubName);
    final messagesRef = _messagesRef.child(clubKey).child('messages');

    return messagesRef.onValue.map((event) {
      if (!event.snapshot.exists) return [];

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final messages = <Message>[];

      data.forEach((key, value) {
        if (value is Map) {
          messages.add(Message.fromMap(key, Map<String, dynamic>.from(value)));
        }
      });

      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    });
  }

  // Mark message as read
  static Future<void> markMessageAsRead(
      String clubName, String messageId) async {
    final clubKey = _safeClubKey(clubName);
    await _messagesRef
        .child(clubKey)
        .child('messages')
        .child(messageId)
        .update({'readByClubHeads': true});
  }

  // Reply to a message
  static Future<void> replyToMessage({
    required String clubName,
    required String messageId,
    required String replyText,
  }) async {
    final clubKey = _safeClubKey(clubName);
    await _messagesRef
        .child(clubKey)
        .child('messages')
        .child(messageId)
        .update({
      'replyText': replyText,
      'replyTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Add reaction to a message
  static Future<void> addReaction({
    required String clubName,
    required String messageId,
    required String emoji,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final clubKey = _safeClubKey(clubName);
    final messageRef =
        _messagesRef.child(clubKey).child('messages').child(messageId);

    final snapshot = await messageRef.child('reactions').child(emoji).get();
    final existingReactions = <Map<String, dynamic>>[];

    if (snapshot.exists) {
      final data = snapshot.value as List;
      for (var r in data) {
        existingReactions.add(Map<String, dynamic>.from(r));
      }
    }

    existingReactions.add({
      'emoji': emoji,
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? 'Member',
    });

    await messageRef.child('reactions').child(emoji).set(existingReactions);
  }

  // Remove reaction from a message
  static Future<void> removeReaction({
    required String clubName,
    required String messageId,
    required String emoji,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final clubKey = _safeClubKey(clubName);
    final messageRef =
        _messagesRef.child(clubKey).child('messages').child(messageId);

    final snapshot = await messageRef.child('reactions').child(emoji).get();
    if (!snapshot.exists) return;

    final data = snapshot.value as List;
    final updatedReactions = <Map<String, dynamic>>[];

    for (var r in data) {
      final reaction = Map<String, dynamic>.from(r);
      if (reaction['userId'] != user.uid) {
        updatedReactions.add(reaction);
      }
    }

    if (updatedReactions.isEmpty) {
      await messageRef.child('reactions').child(emoji).remove();
    } else {
      await messageRef.child('reactions').child(emoji).set(updatedReactions);
    }
  }

  // Get unread message count for a club
  static Stream<int> getUnreadMessageCount(String clubName) {
    final clubKey = _safeClubKey(clubName);
    final messagesRef = _messagesRef.child(clubKey).child('messages');

    return messagesRef.onValue.map((event) {
      if (!event.snapshot.exists) return 0;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      data.forEach((key, value) {
        if (value is Map) {
          final message =
              Message.fromMap(key, Map<String, dynamic>.from(value));
          if (!message.readByClubHeads) unreadCount++;
        }
      });

      return unreadCount;
    });
  }

  // Track last read timestamp for a user in a club
  static Future<void> markClubMessagesAsRead(String clubName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userKey = user.email?.replaceAll('.', ',') ?? user.uid;
    await FirebaseDatabase.instance
        .ref('users/$userKey/clubMessageReadTimes')
        .child(_safeClubKey(clubName))
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  // Get total unread messages across all followed clubs for a user
  static Stream<int> getTotalUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    final userKey = user.email?.replaceAll('.', ',') ?? user.uid;

    return FirebaseDatabase.instance
        .ref('users/$userKey/followedClubs')
        .onValue
        .asyncMap((event) async {
      if (!event.snapshot.exists) return 0;

      final followedClubs = (event.snapshot.value as Map).keys.toList();
      int totalUnread = 0;

      for (final clubName in followedClubs) {
        final clubKey = _safeClubKey(clubName.toString());
        final messagesSnapshot = await FirebaseDatabase.instance
            .ref('clubMessages/$clubKey/messages')
            .get();

        if (messagesSnapshot.exists) {
          final data = messagesSnapshot.value as Map<dynamic, dynamic>;
          final readTimeSnapshot = await FirebaseDatabase.instance
              .ref('users/$userKey/clubMessageReadTimes/$clubKey')
              .get();

          final readTime =
              readTimeSnapshot.exists ? readTimeSnapshot.value as int : 0;

          data.forEach((key, value) {
            if (value is Map) {
              final msgTimestamp = value['timestamp'] as int? ?? 0;
              if (msgTimestamp > readTime) {
                totalUnread++;
              }
            }
          });
        }
      }

      return totalUnread;
    });
  }
}
