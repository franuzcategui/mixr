import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepo {
  ProfileRepo(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select('user_id, display_name, bio, interests')
        .eq('user_id', userId)
        .maybeSingle();

    return response as Map<String, dynamic>?;
  }

  Future<void> upsertMyProfile({
    required String displayName,
    String? bio,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Missing authenticated user.');
    }

    await _client.from('profiles').upsert({
      'user_id': userId,
      'display_name': displayName,
      'bio': bio,
    });
  }
}
