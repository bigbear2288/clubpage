import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/role_service.dart';

class AddAnnouncementPage extends StatefulWidget {
  const AddAnnouncementPage({super.key});

  @override
  State<AddAnnouncementPage> createState() => _AddAnnouncementPageState();
}

class _AddAnnouncementPageState extends State<AddAnnouncementPage> {
  final _messageController = TextEditingController();
  final dbRef = FirebaseDatabase.instance.ref('announcements');

  String? selectedClubName;
  List<Map<String, dynamic>> availableClubs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClubs();
  }

  void _fetchClubs() async {
    if (RoleService.isSuperAdmin()) {
      // Super admin sees ALL clubs
      final snapshot = await FirebaseDatabase.instance.ref('clubs').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        setState(() {
          availableClubs = data.keys
              .map((k) => {'name': k.toString(), 'id': k.toString()})
              .toList()
            ..sort(
                (a, b) => (a['name'] as String).compareTo(b['name'] as String));
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } else {
      // Club heads/advisors only see their clubs
      final clubs = await RoleService.getAdminClubs();
      setState(() {
        availableClubs =
            clubs.map((name) => {'name': name, 'id': name}).toList();
        isLoading = false;
      });
    }
  }

  void _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final message = _messageController.text.trim();

    if (selectedClubName == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    await dbRef.push().set({
      'clubName': selectedClubName,
      'postedBy': user.displayName ?? user.email ?? 'Anonymous',
      'postedByEmail': user.email ?? '',
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Post Announcement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF7A1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Post an Announcement',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  RoleService.isSuperAdmin()
                      ? 'Post as any club'
                      : 'Any updates?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5F6368),
                  ),
                ),
                const SizedBox(height: 32),
                if (availableClubs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are not listed as a head or advisor of any club.',
                            style: TextStyle(color: Color(0xFF5F6368)),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    'Club *',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF202124),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClubName,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select a club',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(
                          color: Color(0xFF7A1E1E),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: availableClubs.map((club) {
                      return DropdownMenuItem<String>(
                        value: club['name'] as String,
                        child: Text(
                          club['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedClubName = value),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Announcement *',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF202124),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'What would you like to announce?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(
                          color: Color(0xFF7A1E1E),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 6,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A1E1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Post Announcement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
