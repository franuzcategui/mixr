import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_card.dart';

class SwipeRepo {
  SwipeRepo(this._client);

  final SupabaseClient _client;

  Future<List<UserCard>> fetchCandidates({
    required String eventId,
    required String currentUserId,
  }) async {
    final membersResponse = await _client
        .from('event_members')
        .select('user_id')
        .eq('event_id', eventId)
        .eq('status', 'joined')
        .eq('role', 'attendee');

    final memberIds = (membersResponse as List<dynamic>)
        .map((row) => row['user_id'] as String)
        .where((id) => id != currentUserId)
        .toSet();

    final swipesResponse = await _client
        .from('swipes')
        .select('swiped_id')
        .eq('event_id', eventId)
        .eq('swiper_id', currentUserId);

    final swipedIds = (swipesResponse as List<dynamic>)
        .map((row) => row['swiped_id'] as String)
        .toSet();

    final candidateIds = memberIds.difference(swipedIds).toList();
    if (candidateIds.isEmpty) {
      return [];
    }

    final profilesResponse = await _client
        .from('profiles')
        .select('user_id, display_name, bio')
        .inFilter('user_id', candidateIds);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final row in profilesResponse as List<dynamic>) {
      profileMap[row['user_id'] as String] = row as Map<String, dynamic>;
    }

    final photosResponse = await _client
        .from('profile_photos')
        .select('user_id, url, sort_order')
        .inFilter('user_id', candidateIds)
        .order('sort_order', ascending: true);

    final photoMap = <String, List<String>>{};
    for (final row in photosResponse as List<dynamic>) {
      final userId = row['user_id'] as String;
      final url = row['url'] as String;
      photoMap.putIfAbsent(userId, () => []).add(url);
    }

    final cards = <UserCard>[];
    for (final entry in profileMap.entries) {
      final userId = entry.key;
      final profile = entry.value;
      cards.add(
        UserCard(
          userId: userId,
          displayName: profile['display_name'] as String? ?? 'Attendee',
          bio: profile['bio'] as String?,
          photoUrls: photoMap[userId] ?? const [],
        ),
      );
    }

    cards.sort((a, b) => a.displayName.compareTo(b.displayName));
    return cards;
  }
}
