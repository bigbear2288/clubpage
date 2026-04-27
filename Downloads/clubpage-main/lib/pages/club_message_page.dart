import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import '../services/message_service.dart';
import '../services/role_service.dart';

class ClubMessagePage extends StatefulWidget {
  final Club club;

  const ClubMessagePage({super.key, required this.club});

  @override
  State<ClubMessagePage> createState() => _ClubMessagePageState();
}

class _ClubMessagePageState extends State<ClubMessagePage> {
  Color get clubColor => widget.club.clubColor;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _isLeader = false;
  bool _isAuthorized = false;
  bool _isCheckingAuth = true;

  static const List<String> _reactionEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🎉'
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _listenToMembership();
  }

  void _listenToMembership() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    FirebaseDatabase.instance
        .ref('users/$userKey/followedClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map && data.containsKey(widget.club.name)) {
        if (!_isAuthorized && !_isLeader) {
          setState(() {
            _isAuthorized = true;
          });
          MessageService.markClubMessagesAsRead(widget.club.name);
        }
      }
    });

    FirebaseDatabase.instance
        .ref('users/$userKey/myClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map && data.containsKey(widget.club.name)) {
        if (!_isAuthorized && !_isLeader) {
          setState(() {
            _isAuthorized = true;
          });
          MessageService.markClubMessagesAsRead(widget.club.name);
        }
      }
    });
  }

  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isCheckingAuth = false);
      return;
    }

    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    final adminClubs = await RoleService.getAdminClubs();
    final isAdmin =
        adminClubs.contains(widget.club.name) || RoleService.isSuperAdmin();

    bool isFollower = false;
    if (!isAdmin) {
      final followedSnapshot = await FirebaseDatabase.instance
          .ref('users/$userKey/followedClubs/${widget.club.name}')
          .get();
      final myClubSnapshot = await FirebaseDatabase.instance
          .ref('users/$userKey/myClubs/${widget.club.name}')
          .get();
      isFollower = followedSnapshot.exists || myClubSnapshot.exists;
    }

    if (!mounted) return;
    setState(() {
      _isLeader = isAdmin;
      _isAuthorized = isAdmin || isFollower;
      _isCheckingAuth = false;
    });

    if (_isAuthorized) {
      await MessageService.markClubMessagesAsRead(widget.club.name);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await MessageService.sendGroupMessage(
        clubName: widget.club.name,
        text: text,
        isLeader: _isLeader,
      );
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.club.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const Text(
              'Group Chat',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: clubColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _isCheckingAuth
          ? const Center(child: CircularProgressIndicator())
          : !_isAuthorized
              ? _buildUnauthorized()
              : Column(
                  children: [
                    // Leader indicator banner
                    if (_isLeader)
                      Container(
                        width: double.infinity,
                        color: clubColor.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.verified, size: 14, color: clubColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'You\'re messaging as a club leader — your messages are highlighted',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: clubColor.withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Messages
                    Expanded(
                      child: StreamBuilder<List<Message>>(
                        stream:
                            MessageService.getGroupMessages(widget.club.name),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final messages = snapshot.data ?? [];

                          if (messages.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No messages yet.\nBe the first to say something!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(
                                  _scrollController.position.maxScrollExtent);
                            }
                          });

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg.senderId ==
                                  FirebaseAuth.instance.currentUser?.uid;
                              return _buildMessageBubble(msg, isMe);
                            },
                          );
                        },
                      ),
                    ),

                    // Input bar
                    _buildInputBar(),
                  ],
                ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    final isLeaderMsg = msg.isLeader;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final hasReacted = msg.reactions.values.any(
      (reactions) => reactions.any((r) => r.userId == userId),
    );

    Color bubbleColor;
    Color textColor;
    if (isMe) {
      bubbleColor = isLeaderMsg ? clubColor : const Color(0xFF1976D2);
      textColor = Colors.white;
    } else if (isLeaderMsg) {
      bubbleColor = clubColor;
      textColor = Colors.white;
    } else {
      bubbleColor = Colors.white;
      textColor = const Color(0xFF212121);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(msg, isLeaderMsg),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    children: [
                      Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLeaderMsg ? clubColor : Colors.grey[600],
                        ),
                      ),
                      if (isLeaderMsg) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: clubColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LEADER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              GestureDetector(
                onTap:
                    !_isLeader && !isMe ? () => _showReactionPicker(msg) : null,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style:
                        TextStyle(fontSize: 15, color: textColor, height: 1.35),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(msg.timestamp),
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                    if (!_isLeader && !isMe) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showReactionPicker(msg),
                        child: Icon(
                          hasReacted
                              ? Icons.add_reaction
                              : Icons.add_reaction_outlined,
                          size: 16,
                          color: hasReacted ? clubColor : Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (msg.reactions.isNotEmpty) _buildReactionsRow(msg),
            ],
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildReactionsRow(Message msg) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: msg.reactions.entries.map((entry) {
          final emoji = entry.key;
          final reactions = entry.value;
          final hasMyReaction = reactions.any((r) => r.userId == userId);

          return GestureDetector(
            onTap: () {
              if (hasMyReaction) {
                MessageService.removeReaction(
                  clubName: widget.club.name,
                  messageId: msg.id,
                  emoji: emoji,
                );
              } else {
                MessageService.addReaction(
                  clubName: widget.club.name,
                  messageId: msg.id,
                  emoji: emoji,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasMyReaction
                    ? clubColor.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasMyReaction ? clubColor : Colors.grey[300]!,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Text(
                    '${reactions.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasMyReaction ? clubColor : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionPicker(Message msg) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'React with emoji',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reactionEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    MessageService.addReaction(
                      clubName: widget.club.name,
                      messageId: msg.id,
                      emoji: emoji,
                    );
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Message msg, bool isLeaderMsg) {
    final initial =
        msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: isLeaderMsg ? clubColor : Colors.grey[300],
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isLeaderMsg ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isLeader
                    ? 'Message club members...'
                    : 'Message ${widget.club.name}...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey[300] : widget.club.clubColor,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthorized() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Members only',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow ${widget.club.name} to join the group chat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
