class Event {
  const Event({
    required this.id,
    required this.name,
    required this.timezone,
    required this.swipeStartAt,
    required this.swipeEndAt,
    required this.isPaid,
    required this.isTestMode,
    required this.testModeAttendeeLimit,
  });

  final String id;
  final String name;
  final String timezone;
  final DateTime swipeStartAt;
  final DateTime swipeEndAt;
  final bool isPaid;
  final bool isTestMode;
  final int testModeAttendeeLimit;
}
