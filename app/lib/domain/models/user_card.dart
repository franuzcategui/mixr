class UserCard {
  const UserCard({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.photoUrls,
  });

  final String userId;
  final String displayName;
  final String? bio;
  final List<String> photoUrls;
}
