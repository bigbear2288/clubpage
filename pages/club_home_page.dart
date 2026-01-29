// import 'package:flutter/material.dart';
// import '../models/club.dart';

// class ClubHomePage extends StatelessWidget {
//   final Club club;

//   const ClubHomePage({super.key, required this.club});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(club.name)),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Advisor 1: ${club.advisor1 ?? "N/A"}'),
//             Text('Advisor 2: ${club.advisor2 ?? "N/A"}'),
//             Text('Head 1: ${club.head1 ?? "N/A"}'),
//             Text('Head 2: ${club.head2 ?? "N/A"}'),
//             Text('Email Head 1: ${club.emailHead1 ?? "N/A"}'),
//             Text('Email Head 2: ${club.emailHead2 ?? "N/A"}'),
//             Text('Room: ${club.room ?? "N/A"}'),
//             Text('Schedule: ${club.schedule ?? "N/A"}'),
//             Text('Time: ${club.time ?? "N/A"}'),
//           ],
//         ),
//       ),
//     );
//   }
// }


// new format from claude

import 'package:flutter/material.dart';
import '../models/club.dart';

class ClubHomePage extends StatelessWidget {
  final Club club;

  const ClubHomePage({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(club.name),
        backgroundColor: Colors.deepPurple,
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
                  colors: [Colors.deepPurple, Colors.deepPurple.shade300],
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
                      club.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    club.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Meeting Info Card
                  _buildInfoCard(
                    context,
                    title: 'Meeting Information',
                    icon: Icons.event,
                    children: [
                      _buildInfoRow(Icons.schedule, 'Schedule', club.schedule),
                      _buildInfoRow(Icons.access_time, 'Time', club.time),
                      _buildInfoRow(Icons.room, 'Room', club.room),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Leadership Card
                  _buildInfoCard(
                    context,
                    title: 'Leadership',
                    icon: Icons.people,
                    children: [
                      _buildLeaderTile('Club Head', club.head1, club.emailHead1),
                      if (club.head2 != null)
                        _buildLeaderTile('Co-Head', club.head2, club.emailHead2),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Advisors Card
                  _buildInfoCard(
                    context,
                    title: 'Faculty Advisors',
                    icon: Icons.school,
                    children: [
                      _buildAdvisorTile(club.advisor1),
                      if (club.advisor2 != null)
                        _buildAdvisorTile(club.advisor2),
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

  Widget _buildInfoCard(
    BuildContext context, {
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
                Icon(icon, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderTile(String role, String? name, String? email) {
    if (name == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (email != null)
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple[300],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorTile(String? name) {
    if (name == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.person, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}