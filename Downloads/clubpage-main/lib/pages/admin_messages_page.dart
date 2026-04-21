import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/message_service.dart';
import '../services/role_service.dart';

class JoinRequest {
  final String userId;
  final String userName;
  final String userEmail;
  final String status;
  final int timestamp;

  JoinRequest({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.status,
    required this.timestamp,
  });

  factory JoinRequest.fromMap(String userId, Map<String, dynamic> data) {
    return JoinRequest(
      userId: userId,
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      status: data['status'] ?? '',
      timestamp: data['timestamp'] ?? 0,
    );
  }
}

class AdminMessagesPage extends StatefulWidget {
  const AdminMessagesPage({super.key});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  List<String> _adminClubs = [];
  bool _isLoading = true;
  String? _selectedClub;
  List<Message> _messages = [];
  List<JoinRequest> _joinRequests = [];
  bool _isLoadingMessages = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminClubs();
  }

  Future<void> _loadAdminClubs() async {
    try {
      final adminClubs = await RoleService.getAdminClubs();
      setState(() {
        _adminClubs = adminClubs;
        _isLoading = false;
        if (adminClubs.isNotEmpty) {
          _selectedClub = adminClubs.first;
          _loadMessages();
          _loadJoinRequests();
        }
      });
    } catch (e) {
      debugPrint('Error loading admin clubs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMessages() {
    if (_selectedClub == null) return;

    setState(() {
      _isLoadingMessages = true;
    });

    MessageService.getMessagesForClub(_selectedClub!).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
      }
    });
  }

  void _loadJoinRequests() {
    if (_selectedClub == null) return;

    FirebaseDatabase.instance
        .ref('joinRequests/$_selectedClub')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        final requests = <JoinRequest>[];
        data.forEach((userId, value) {
          if (value is Map) {
            requests.add(JoinRequest.fromMap(
              userId,
              Map<String, dynamic>.from(value),
            ));
          }
        });
        requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        setState(() {
          _joinRequests = requests.where((r) => r.status == 'pending').toList();
        });
      } else {
        setState(() {
          _joinRequests = [];
        });
      }
    });
  }

  Future<void> _handleJoinRequest(JoinRequest request, bool accept) async {
    if (_selectedClub == null) return;

    final userKey = request.userEmail.replaceAll('.', ',');

    if (accept) {
      await FirebaseDatabase.instance
          .ref('users/$userKey/myClubs/$_selectedClub')
          .set(true);
      await FirebaseDatabase.instance
          .ref('users/$userKey/followedClubs/$_selectedClub')
          .set(true);
      await FirebaseDatabase.instance
          .ref('joinRequests/$_selectedClub/${request.userId}')
          .update({'status': 'accepted'});
      await FirebaseDatabase.instance
          .ref('users/$userKey/joinRequests/$_selectedClub')
          .update({'status': 'accepted'});
    } else {
      await FirebaseDatabase.instance
          .ref('joinRequests/$_selectedClub/${request.userId}')
          .update({'status': 'declined'});
      await FirebaseDatabase.instance
          .ref('users/$userKey/joinRequests/$_selectedClub')
          .update({'status': 'declined'});
    }
  }

  Future<void> _markAsRead(Message message) async {
    try {
      await MessageService.markMessageAsRead(message.clubName, message.id);
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  Future<void> _replyToMessage(Message message) async {
    final TextEditingController replyController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('From: ${message.senderName} (${message.senderEmail})'),
            const SizedBox(height: 8),
            Text('"${message.text}"'),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type your reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(replyController.text.trim()),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await MessageService.replyToMessage(
          clubName: message.clubName,
          messageId: message.id,
          replyText: result,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply sent successfully')),
          );
        }
      } catch (e) {
        debugPrint('Error sending reply: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send reply')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Club Messages'),
          backgroundColor: const Color(0xFF7A1E1E),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_adminClubs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Club Messages'),
          backgroundColor: const Color(0xFF7A1E1E),
        ),
        body: const Center(
          child: Text('You are not an admin for any clubs.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Club Messages'),
        backgroundColor: const Color(0xFF7A1E1E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedClub,
                  decoration: const InputDecoration(
                    labelText: 'Select Club',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _adminClubs.map((club) {
                    return DropdownMenuItem(
                      value: club,
                      child: Text(club),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClub = value;
                      _selectedTab = 0;
                    });
                    _loadMessages();
                    _loadJoinRequests();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _selectedTab == 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7A1E1E),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Messages',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => setState(() => _selectedTab = 0),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  'Messages',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _joinRequests.isNotEmpty
                          ? Stack(
                              children: [
                                _selectedTab == 1
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7A1E1E),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Join Requests',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${_joinRequests.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () =>
                                            setState(() => _selectedTab = 1),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Join Requests',
                                                style: TextStyle(
                                                    color: Colors.grey[700]),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '${_joinRequests.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ],
                            )
                          : GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1
                                      ? const Color(0xFF7A1E1E)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  'Join Requests',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedTab == 1
                                        ? Colors.white
                                        : Colors.grey[700],
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
          Expanded(
            child: _selectedTab == 0
                ? _buildMessagesList()
                : _buildJoinRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return _isLoadingMessages
        ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty
            ? const Center(child: Text('No messages yet.'))
            : ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  message.senderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (!message.readByClubHeads)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.senderEmail,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(message.text),
                          const SizedBox(height: 8),
                          Text(
                            _formatTimestamp(message.timestamp),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!message.readByClubHeads)
                                TextButton(
                                  onPressed: () => _markAsRead(message),
                                  child: const Text('Mark as Read'),
                                ),
                              if (message.replyText == null)
                                ElevatedButton(
                                  onPressed: () => _replyToMessage(message),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7A1E1E),
                                  ),
                                  child: const Text('Reply'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }

  Widget _buildJoinRequestsList() {
    return _joinRequests.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_add, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No pending join requests',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          )
        : ListView.builder(
            itemCount: _joinRequests.length,
            itemBuilder: (context, index) {
              final request = _joinRequests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF7A1E1E),
                            child: Text(
                              request.userName.isNotEmpty
                                  ? request.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  request.userEmail,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Wants to join ${_selectedClub ?? ""}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _handleJoinRequest(request, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleJoinRequest(request, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
