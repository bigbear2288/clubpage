import 'package:flutter/material.dart';
import '../models/club.dart';

class ClubHomePage extends StatelessWidget {
  final Club club;

  const ClubHomePage({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(club.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Advisor 1: ${club.advisor1 ?? "N/A"}'),
            Text('Advisor 2: ${club.advisor2 ?? "N/A"}'),
            Text('Head 1: ${club.head1 ?? "N/A"}'),
            Text('Head 2: ${club.head2 ?? "N/A"}'),
            Text('Email Head 1: ${club.emailHead1 ?? "N/A"}'),
            Text('Email Head 2: ${club.emailHead2 ?? "N/A"}'),
            Text('Room: ${club.room ?? "N/A"}'),
            Text('Schedule: ${club.schedule ?? "N/A"}'),
            Text('Time: ${club.time ?? "N/A"}'),
          ],
        ),
      ),
    );
  }
}
