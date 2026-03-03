class Club {
  final String name;
  final String? advisor1;
  final String? advisor2;
  final String? head1;
  final String? head2;
  final String? head3; // ADD
  final String? head4; // ADD
  final String? emailHead1;
  final String? emailHead2;
  final String? emailHead3;
  final String? emailHead4;
  final String? room;
  final String? schedule;
  final String? time;

  Club({
    required this.name,
    this.advisor1,
    this.advisor2,
    this.head1,
    this.head2,
    this.head3, // ADD
    this.head4, // ADD
    this.emailHead1,
    this.emailHead2,
    this.emailHead3,
    this.emailHead4,
    this.room,
    this.schedule,
    this.time,
  });

  factory Club.fromMap(Map<String, dynamic> data) {
    return Club(
      name: data['name'] ?? '',
      advisor1: data['advisor1'],
      advisor2: data['advisor2'],
      head1: data['head1'],
      head2: data['head2'],
      head3: data['head3'], // ADD
      head4: data['head4'], // ADD
      emailHead1: data['email_head1'],
      emailHead2: data['email_head2'],
      emailHead3: data['email_head3'],
      emailHead4: data['email_head4'],
      room: data['room'],
      schedule: data['schedule'],
      time: data['time'],
    );
  }
}
