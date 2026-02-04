class Club {
  final String name;
  final String? advisor1;
  final String? advisor2;
  final String? head1;
  final String? head2;
  final String? emailHead1;
  final String? emailHead2;
  final String? room;
  final String? schedule;
  final String? time;
  final String? description;

  Club({
    required this.name,
    this.advisor1,
    this.advisor2,
    this.head1,
    this.head2,
    this.emailHead1,
    this.emailHead2,
    this.room,
    this.schedule,
    this.time,
    this.description,
  });

  factory Club.fromMap(Map<String, dynamic> data) {
    return Club(
      name: data['name'] ?? '',
      advisor1: data['advisor1'],
      advisor2: data['advisor2'],
      head1: data['head1'],
      head2: data['head2'],
      emailHead1: data['email_head1'],
      emailHead2: data['email_head2'],
      room: data['room'],
      schedule: data['schedule'],
      time: data['time'],
      description: data['description'],
    );
  }
}
