import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/club.dart';
import '../services/role_service.dart';

class ClubHomePage extends StatefulWidget {
  final Club club;
  const ClubHomePage({super.key, required this.club});

  @override
  State<ClubHomePage> createState() => _ClubHomePageState();
}

class _ClubHomePageState extends State<ClubHomePage> {
  static const Color maroonColor = Color.fromARGB(255, 122, 30, 30);

  bool isAdmin = false;
  late Club club;

  // Block schedule config
  static const List<String> blocks = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'Activities'
  ];

  static const Map<String, Color> blockColors = {
    'A': Color(0xFFEF9A9A),
    'B': Color(0xFFFFCC80),
    'C': Color(0xFFFFF59D),
    'D': Color(0xFFA5D6A7),
    'E': Color(0xFF90CAF9),
    'F': Color(0xFFCE93D8),
    'G': Color(0xFF80DEEA),
    'H': Color(0xFFFFAB91),
    'Activities': Color(0xFFB0BEC5),
  };

  @override
  void initState() {
    super.initState();
    club = widget.club;
    _checkAdminStatus();
    _listenToClubUpdates();
  }

  Future<void> _checkAdminStatus() async {
    final adminClubs = await RoleService.getAdminClubs();
    if (!mounted) return;
    setState(() {
      isAdmin = adminClubs.contains(club.name);
    });
  }

  // Realtime listener so all users see updates instantly
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
              // _listenToClubUpdates handles UI update
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editScheduleDays() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final currentSchedule = club.schedule ?? '';
    final selected = <String>{};
    for (var day in days) {
      if (currentSchedule.contains(day)) selected.add(day);
    }

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
                    if (checked == true) {
                      selected.add(day);
                    } else {
                      selected.remove(day);
                    }
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
    String? selectedBlock = club.meetingBlock;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Meeting Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: blocks.map((block) {
              final color = blockColors[block] ?? Colors.grey[200]!;
              return RadioListTile<String>(
                title: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                        '$block Block${block == 'Activities' ? ' (Wed only)' : ''}'),
                  ],
                ),
                value: block,
                groupValue: selectedBlock,
                activeColor: maroonColor,
                onChanged: (val) {
                  setDialogState(() => selectedBlock = val);
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
                if (selectedBlock != null) {
                  await FirebaseDatabase.instance
                      .ref('clubs/${club.name}/block')
                      .set(selectedBlock);
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockColor = club.meetingBlock != null
        ? blockColors[club.meetingBlock] ?? Colors.grey[200]!
        : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(club.name),
        backgroundColor: maroonColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header banner
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [maroonColor, maroonColor.withOpacity(0.7)],
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
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: maroonColor,
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
                  if (club.meetingBlock != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: blockColor?.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${club.meetingBlock} Block${club.meetingBlock == 'Activities' ? ' (Wednesdays)' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF424242),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
                      child: const Text(
                        '⚙️ Admin',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Meeting Info Card
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
                      _buildEditableRow(
                        Icons.grid_view,
                        'Block',
                        club.meetingBlock != null
                            ? '${club.meetingBlock} Block'
                            : null,
                        blockColor: blockColor,
                        onEdit: isAdmin ? () => _editBlock() : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Leadership Card
                  _buildInfoCard(
                    title: 'Leadership',
                    icon: Icons.people,
                    children: [
                      _buildLeaderTile(
                          'Club Head', club.head1, club.emailHead1),
                      if (club.head2 != null && club.head2!.isNotEmpty)
                        _buildLeaderTile(
                            'Club Head', club.head2, club.emailHead2),
                      if (club.head3 != null && club.head3!.isNotEmpty)
                        _buildLeaderTile(
                            'Club Head', club.head3, club.emailHead3),
                      if (club.head4 != null && club.head4!.isNotEmpty)
                        _buildLeaderTile(
                            'Club Head', club.head4, club.emailHead4),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Advisors Card
                  _buildInfoCard(
                    title: 'Faculty Advisors',
                    icon: Icons.school,
                    children: [
                      _buildAdvisorTile(
                        club.advisor1,
                        club.emailAdvisor1,
                        emailFieldKey: 'email_advisor1',
                      ),
                      if (club.advisor2 != null && club.advisor2!.isNotEmpty)
                        _buildAdvisorTile(
                          club.advisor2,
                          club.emailAdvisor2,
                          emailFieldKey: 'email_advisor2',
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

  Widget _buildLeaderTile(String role, String? name, String? email) {
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
                  Text(email,
                      style: const TextStyle(fontSize: 12, color: maroonColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorTile(String? name, String? email,
      {String? emailFieldKey}) {
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
                  Text(email,
                      style: const TextStyle(fontSize: 12, color: maroonColor)),
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
          if (isAdmin &&
              emailFieldKey != null &&
              email != null &&
              email.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: maroonColor),
              onPressed: () =>
                  _editField('Advisor Email', emailFieldKey, email),
            ),
        ],
      ),
    );
  }
}
