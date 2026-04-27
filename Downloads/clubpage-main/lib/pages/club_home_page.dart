import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import '../services/role_service.dart';
import 'club_message_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class ClubHomePage extends StatefulWidget {
  final Club club;
  const ClubHomePage({super.key, required this.club});

  @override
  State<ClubHomePage> createState() => _ClubHomePageState();
}

class _ClubHomePageState extends State<ClubHomePage> {
  static const Color maroonColor = Color.fromARGB(255, 122, 30, 30);

  bool isAdmin = false;
  bool isSuperAdmin = false;
  int? followerCount;
  List<String>? followerList;
  late Club club;
  bool isFollowing = false;
  String? joinRequestStatus;
  bool isMyClub = false;

  Color get clubColor => club.clubColorValue != null
      ? Color(club.clubColorValue!)
      : Club.defaultColor;

  @override
  void initState() {
    super.initState();
    club = widget.club;
    isSuperAdmin = RoleService.isSuperAdmin();
    _checkAdminStatus();
    _listenToClubUpdates();
    _listenToFollowStatus();
    _checkJoinRequestStatus();
    if (isSuperAdmin) _loadFollowers();
  }

  Future<void> _checkJoinRequestStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    FirebaseDatabase.instance
        .ref('users/$userKey/joinRequests/${club.name}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          joinRequestStatus = data['status'] as String?;
        });
      } else {
        setState(() {
          joinRequestStatus = null;
        });
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    final adminClubs = await RoleService.getAdminClubs();
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;
    setState(() {
      isAdmin = isSuperAdmin || adminClubs.contains(club.name);
    });

    if (isAdmin && user != null) {
      final userKey = (user.email ?? user.uid).replaceAll('.', ',');
      final myClubsRef =
          FirebaseDatabase.instance.ref('users/$userKey/myClubs/${club.name}');
      final snapshot = await myClubsRef.get();
      if (!snapshot.exists) {
        await myClubsRef.set(true);
        await FirebaseDatabase.instance
            .ref('users/$userKey/followedClubs/${club.name}')
            .set(true);
      }
    }
  }

  void _listenToFollowStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userKey = (user.email ?? user.uid).replaceAll('.', ',');

    FirebaseDatabase.instance
        .ref('users/$userKey/followedClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      setState(() {
        if (data is Map) {
          isFollowing = data.containsKey(club.name);
        } else {
          isFollowing = false;
        }
      });
    });

    FirebaseDatabase.instance
        .ref('users/$userKey/myClubs')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      setState(() {
        if (data is Map) {
          isMyClub = data.containsKey(club.name);
        }
      });
    });
  }

  Future<void> _toggleFollow() async {
    final wasFollowing = isFollowing;
    setState(() => isFollowing = !isFollowing);
    try {
      if (wasFollowing) {
        await UserService.unfollowClub(club.name);
      } else {
        await UserService.followClub(club.name);
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClubMessagePage(club: club),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isFollowing = wasFollowing);
      debugPrint('Error toggling follow: $e');
    }
  }

  Future<void> _loadFollowers() async {
    final count = await RoleService.getFollowerCount(club.name);
    final followers = await RoleService.getFollowers(club.name);
    if (!mounted) return;
    setState(() {
      followerCount = count;
      followerList = followers;
    });
  }

  void _listenToClubUpdates() {
    FirebaseDatabase.instance.ref('clubs/${club.name}').onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        final clubMap = Map<String, dynamic>.from(data);
        clubMap['name'] = club.name;
        setState(() {
          club = Club.fromMap(clubMap);
        });
      }
    });
  }

  void _editField(String fieldLabel, String fieldKey, String? currentValue) {
    final controller = TextEditingController(text: currentValue ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $fieldLabel'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter $fieldLabel'),
          autofocus: true,
          maxLines: fieldKey == 'description' ? 5 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: maroonColor),
            onPressed: () async {
              await FirebaseDatabase.instance
                  .ref('clubs/${club.name}/$fieldKey')
                  .set(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editCategory() {
    const defaultCategories = [
      'Academic',
      'Affinity and Cultural',
      'Creative and Performing Arts',
      'Environmental',
      'Health and Wellness',
      'Media and Publications',
      'Political and Advocacy',
      'Service',
      'Special Interest',
    ];

    final categories = [
      ...defaultCategories,
      if (club.category != null &&
          club.category!.isNotEmpty &&
          !defaultCategories.contains(club.category))
        club.category!,
    ];

    String? selected =
        categories.contains(club.category) ? club.category : null;
    bool isAddingCustom = false;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isAddingCustom) ...[
                DropdownButton<String>(
                  value: selected,
                  isExpanded: true,
                  hint: const Text('Select a category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selected = val),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setDialogState(() {
                    isAddingCustom = true;
                    selected = null;
                  }),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 18, color: maroonColor),
                      SizedBox(width: 6),
                      Text(
                        'Add custom category',
                        style: TextStyle(
                          color: maroonColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextField(
                  controller: customController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter custom category',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setDialogState(() {
                    isAddingCustom = false;
                    customController.clear();
                  }),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Back to list',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: maroonColor),
              onPressed: () async {
                final value =
                    isAddingCustom ? customController.text.trim() : selected;
                if (value == null || value.isEmpty) return;
                await FirebaseDatabase.instance
                    .ref('clubs/${club.name}/category')
                    .set(value);
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _editScheduleDays() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final currentSchedule = club.schedule ?? '';
    final selected = <String>{
      for (var d in days)
        if (currentSchedule.contains(d)) d
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Meeting Days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: days.map((day) {
              return CheckboxListTile(
                title: Text(day),
                value: selected.contains(day),
                activeColor: maroonColor,
                onChanged: (checked) {
                  setDialogState(() {
                    checked == true ? selected.add(day) : selected.remove(day);
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: maroonColor),
              onPressed: () async {
                final newSchedule =
                    days.where((d) => selected.contains(d)).join(', ');
                await FirebaseDatabase.instance
                    .ref('clubs/${club.name}/schedule')
                    .set(newSchedule);
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _editBlock() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final currentBlocks = club.meetingBlock?.split(', ').toSet() ?? {};
    final Map<String, bool> dayFlexSelected = {};
    for (var day in days) {
      final flexOption = '${day.substring(0, 3)} HS Flex';
      dayFlexSelected[day] = currentBlocks.contains(flexOption);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Meeting Time'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HS Flex (11:30-11:55)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...days.map((day) {
                  return CheckboxListTile(
                    title: Text('$day - HS Flex'),
                    value: dayFlexSelected[day] ?? false,
                    activeColor: maroonColor,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setDialogState(() {
                        dayFlexSelected[day] = val ?? false;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: maroonColor),
              onPressed: () async {
                final List<String> result = [];
                for (var day in days) {
                  if (dayFlexSelected[day] ?? false) {
                    result.add('${day.substring(0, 3)} HS Flex');
                  }
                }
                final newBlockValue = result.isEmpty ? null : result.join(', ');
                await FirebaseDatabase.instance
                    .ref('clubs/${club.name}/block')
                    .set(newBlockValue);
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFollowers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${club.name} Followers (${followerCount ?? 0})'),
        content: SizedBox(
          width: double.maxFinite,
          child: followerList == null || followerList!.isEmpty
              ? const Text('No followers yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: followerList!.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: maroonColor),
                        const SizedBox(width: 8),
                        Text(followerList![i]),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(club.name),
        backgroundColor: clubColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: 'Message club head',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClubMessagePage(club: club),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [clubColor, clubColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Text(
                      club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: clubColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    club.name.isNotEmpty ? club.name : 'Unknown Club',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Category badge
                  if (club.category != null && club.category!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Text(
                        club.category!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSuperAdmin ? '⚙️ Super Admin' : '⚙️ Admin',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                  if (isSuperAdmin && followerCount != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showFollowers,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$followerCount follower${followerCount != 1 ? 's' : ''} — tap to view',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      if (isMyClub) {
                        return;
                      }
                      if (joinRequestStatus == 'pending') {
                        UserService.cancelJoinRequest(club.name);
                      } else if (club.requiresJoinRequest) {
                        UserService.requestToJoin(club.name);
                      } else {
                        _toggleFollow();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isFollowing || isMyClub
                            ? Colors.pink
                            : (joinRequestStatus == 'pending'
                                ? Colors.orange
                                : (club.requiresJoinRequest
                                    ? Colors.blue
                                    : Colors.pink)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFollowing || isMyClub
                              ? Colors.pink
                              : (joinRequestStatus == 'pending'
                                  ? Colors.orange
                                  : (club.requiresJoinRequest
                                      ? Colors.blue
                                      : Colors.pink)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFollowing || isMyClub
                                ? Icons.favorite
                                : (joinRequestStatus == 'pending'
                                    ? Icons.hourglass_empty
                                    : (club.requiresJoinRequest
                                        ? Icons.person_add
                                        : Icons.favorite_border)),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isMyClub
                                ? 'Member'
                                : (isFollowing
                                    ? 'Following'
                                    : (joinRequestStatus == 'pending'
                                        ? 'Request Sent'
                                        : (club.requiresJoinRequest
                                            ? 'Request to Join'
                                            : 'Follow'))),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildInfoCard(
                    title: 'About',
                    icon: Icons.info_outline,
                    children: [
                      _buildEditableRow(
                        Icons.category,
                        'Category',
                        club.category,
                        onEdit: isSuperAdmin ? _editCategory : null,
                      ),
                      _buildEditableRow(
                        Icons.description,
                        'Description',
                        club.description,
                        onEdit: isAdmin
                            ? () => _editField(
                                'Description', 'description', club.description)
                            : null,
                      ),
                      if (isAdmin)
                        _buildSwitchRow(
                          'Require Join Request',
                          club.requiresJoinRequest,
                          (value) async {
                            await FirebaseDatabase.instance
                                .ref('clubs/${club.name}/requiresJoinRequest')
                                .set(value);
                          },
                        ),
                      if (isAdmin)
                        _buildColorPickerRow(
                          'Club Color',
                          club.clubColorValue,
                          (value) async {
                            await FirebaseDatabase.instance
                                .ref('clubs/${club.name}/clubColorValue')
                                .set(value);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Meeting Information',
                    icon: Icons.event,
                    children: [
                      _buildEditableRow(
                        Icons.calendar_today,
                        'Schedule',
                        club.schedule,
                        onEdit: isAdmin ? () => _editScheduleDays() : null,
                      ),
                      _buildEditableRow(
                        Icons.access_time,
                        'Time',
                        club.time,
                        onEdit: isAdmin
                            ? () => _editField('Time', 'time', club.time)
                            : null,
                      ),
                      _buildEditableRow(
                        Icons.room,
                        'Room',
                        club.room,
                        onEdit: isAdmin
                            ? () => _editField('Room', 'room', club.room)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Leadership',
                    icon: Icons.people,
                    children: [
                      _buildLeaderTile('Club Head', club.head1, club.emailHead1,
                          onEditName: isSuperAdmin
                              ? () =>
                                  _editField('Head 1 Name', 'head1', club.head1)
                              : null,
                          onEditEmail: isSuperAdmin
                              ? () => _editField('Head 1 Email', 'email_head1',
                                  club.emailHead1)
                              : null),
                      if (club.head2 != null && club.head2!.isNotEmpty)
                        _buildLeaderTile(
                            'Club Head', club.head2, club.emailHead2,
                            onEditName: isSuperAdmin
                                ? () => _editField(
                                    'Head 2 Name', 'head2', club.head2)
                                : null,
                            onEditEmail: isSuperAdmin
                                ? () => _editField('Head 2 Email',
                                    'email_head2', club.emailHead2)
                                : null),
                      if (club.head3 != null && club.head3!.isNotEmpty)
                        _buildLeaderTile(
                            'Club Head', club.head3, club.emailHead3,
                            onEditName: isSuperAdmin
                                ? () => _editField(
                                    'Head 3 Name', 'head3', club.head3)
                                : null,
                            onEditEmail: isSuperAdmin
                                ? () => _editField('Head 3 Email',
                                    'email_head3', club.emailHead3)
                                : null),
                      if (club.head4 != null && club.head4!.isNotEmpty)
                        _buildLeaderTile(
                            'Club Head', club.head4, club.emailHead4,
                            onEditName: isSuperAdmin
                                ? () => _editField(
                                    'Head 4 Name', 'head4', club.head4)
                                : null,
                            onEditEmail: isSuperAdmin
                                ? () => _editField('Head 4 Email',
                                    'email_head4', club.emailHead4)
                                : null),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Faculty Advisors',
                    icon: Icons.school,
                    children: [
                      _buildAdvisorTile(
                        club.advisor1,
                        club.emailAdvisor1,
                        emailFieldKey: 'email_advisor1',
                        onEditName: isSuperAdmin
                            ? () => _editField(
                                'Advisor 1', 'advisor1', club.advisor1)
                            : null,
                      ),
                      if (club.advisor2 != null && club.advisor2!.isNotEmpty)
                        _buildAdvisorTile(
                          club.advisor2,
                          club.emailAdvisor2,
                          emailFieldKey: 'email_advisor2',
                          onEditName: isSuperAdmin
                              ? () => _editField(
                                  'Advisor 2', 'advisor2', club.advisor2)
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: maroonColor, size: 24),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(Icons.toggle_on, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: maroonColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  static const List<Color> clubColorOptions = [
    Color(0xFF7A1E1E),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFF57C00),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFC62828),
    Color(0xFF4527A0),
    Color(0xFF00897B),
    Color(0xFFAD1457),
    Color(0xFF37474F),
    Color(0xFF5D4037),
  ];

  Widget _buildColorPickerRow(
    String label,
    int? currentColorValue,
    Function(int) onChanged,
  ) {
    final currentColor =
        currentColorValue != null ? Color(currentColorValue) : maroonColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: clubColorOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final color = clubColorOptions[index];
                final isSelected = color.value == currentColor.value;
                return GestureDetector(
                  onTap: () => onChanged(color.value),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(
    IconData icon,
    String label,
    String? value, {
    VoidCallback? onEdit,
    Color? blockColor,
  }) {
    if ((value == null || value.isEmpty) && onEdit == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                if (blockColor != null && value != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF424242)),
                    ),
                  )
                else
                  Text(
                    value?.isNotEmpty == true ? value! : 'Not set',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: value?.isNotEmpty == true
                          ? Colors.black
                          : Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: maroonColor),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderTile(
    String role,
    String? name,
    String? email, {
    VoidCallback? onEditName,
    VoidCallback? onEditEmail,
  }) {
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: maroonColor.withOpacity(0.1),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                  color: maroonColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(role,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (email != null && email.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(email,
                            style: const TextStyle(fontSize: 12, color: maroonColor)),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy, size: 12, color: maroonColor),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (onEditName != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: maroonColor),
              onPressed: onEditName,
            ),
          if (onEditEmail != null)
            IconButton(
              icon: const Icon(Icons.email, size: 18, color: maroonColor),
              onPressed: onEditEmail,
            ),
        ],
      ),
    );
  }

  Widget _buildAdvisorTile(
    String? name,
    String? email, {
    String? emailFieldKey,
    VoidCallback? onEditName,
  }) {
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.grey[700], fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Text('Advisor',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                if (email != null && email.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(email,
                            style: const TextStyle(fontSize: 12, color: maroonColor)),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy, size: 12, color: maroonColor),
                      ],
                    ),
                  ),
                if ((email == null || email.isEmpty) &&
                    isAdmin &&
                    emailFieldKey != null)
                  GestureDetector(
                    onTap: () =>
                        _editField('Advisor Email', emailFieldKey, email),
                    child: const Text('+ Add email',
                        style: TextStyle(fontSize: 12, color: maroonColor)),
                  ),
              ],
            ),
          ),
          if (onEditName != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: maroonColor),
              onPressed: onEditName,
            ),
          if (isAdmin &&
              emailFieldKey != null &&
              email != null &&
              email.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.email, size: 18, color: maroonColor),
              onPressed: () =>
                  _editField('Advisor Email', emailFieldKey, email),
            ),
        ],
      ),
    );
  }
}
