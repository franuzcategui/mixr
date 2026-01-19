class Match {
  const Match({
    required this.eventId,
    required this.userId,
    required this.matchedUserId,
    required this.createdAt,
    this.expiresAt,
  });

  final String eventId;
  final String userId;
  final String matchedUserId;
  final DateTime createdAt;
  final DateTime? expiresAt;
}
