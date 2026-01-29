import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AddAnnouncementPage extends StatefulWidget {
  const AddAnnouncementPage({super.key});

  @override
  State<AddAnnouncementPage> createState() => _AddAnnouncementPageState();
}

class _AddAnnouncementPageState extends State<AddAnnouncementPage> {
  final _clubController = TextEditingController();
  final _messageController = TextEditingController();
  final dbRef = FirebaseDatabase.instance.ref('announcements');

  void _submit() async {
    final clubName = _clubController.text.trim();
    final message = _messageController.text.trim();

    if (clubName.isEmpty || message.isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await dbRef.push().set({
      'clubName': clubName,
      'message': message,
      'timestamp': timestamp,
    });

    Navigator.pop(context); // go back to bulletin board
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Announcement'),
        backgroundColor: const Color(0xFF7A1E1E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Club name input
            TextField(
              controller: _clubController,
              decoration: const InputDecoration(
                labelText: 'Club Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Announcement message
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Announcement',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A1E1E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Post Announcement'),
            ),
          ],
        ),
      ),
    );
  }
}
