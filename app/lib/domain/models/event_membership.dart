class EventMembership {
  const EventMembership({
    required this.eventId,
    required this.userId,
    required this.joinedAt,
  });

  final String eventId;
  final String userId;
  final DateTime joinedAt;
}
