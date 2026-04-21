import 'package:flutter/material.dart';

class Club {
  static const Color defaultColor = Color(0xFF7A1E1E);

  final String name;
  final String? advisor1;
  final String? advisor2;
  final String? head1;
  final String? head2;
  final String? head3;
  final String? head4;
  final String? emailHead1;
  final String? emailHead2;
  final String? emailHead3;
  final String? emailHead4;
  final String? emailAdvisor1; // ADD
  final String? emailAdvisor2; // ADD
  final String? room;
  final String? schedule;
  final String? meetingBlock; // ADD
  final String? category;
  final String? time;
  final String? description;
  final bool requiresJoinRequest;
  final int? clubColorValue;

  Club({
    required this.name,
    this.advisor1,
    this.advisor2,
    this.head1,
    this.head2,
    this.head3,
    this.head4,
    this.emailHead1,
    this.emailHead2,
    this.emailHead3,
    this.emailHead4,
    this.emailAdvisor1, // ADD
    this.emailAdvisor2, // ADD
    this.room,
    this.schedule,
    this.meetingBlock, // ADD
    this.category,
    this.time,
    this.description,
    this.requiresJoinRequest = false,
    this.clubColorValue,
  });

  Color get clubColor =>
      clubColorValue != null ? Color(clubColorValue!) : defaultColor;

  factory Club.fromMap(Map<String, dynamic> data) {
    return Club(
      name: data['name'] ?? '',
      advisor1: data['advisor1'],
      advisor2: data['advisor2'],
      head1: data['head1'],
      head2: data['head2'],
      head3: data['head3'],
      head4: data['head4'],
      emailHead1: data['email_head1'],
      emailHead2: data['email_head2'],
      emailHead3: data['email_head3'],
      emailHead4: data['email_head4'],
      emailAdvisor1: data['email_advisor1'], // ADD
      emailAdvisor2: data['email_advisor2'], // ADD
      room: data['room'],
      schedule: data['schedule'],
      meetingBlock: data['block'], // ADD
      category: data['category'],
      time: data['time'],
      description: data['description'],
      requiresJoinRequest: data['requiresJoinRequest'] ?? false,
      clubColorValue: data['clubColorValue'],
    );
  }
}
