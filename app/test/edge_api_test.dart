import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app/data/api/edge_api.dart';

void main() {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const supabaseRefreshToken = String.fromEnvironment('SUPABASE_REFRESH_TOKEN');

  const joinToken = String.fromEnvironment('JOIN_EVENT_TOKEN');
  const eventId = String.fromEnvironment('EVENT_ID');
  const swipedId = String.fromEnvironment('SWIPED_ID');
  const direction = String.fromEnvironment(
    'SWIPE_DIRECTION',
    defaultValue: 'right',
  );

  final hasSupabaseEnv = supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseRefreshToken.isNotEmpty;

  setUpAll(() async {
    if (!hasSupabaseEnv) {
      return;
    }

    TestWidgetsFlutterBinding.ensureInitialized();

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    await Supabase.instance.client.auth.setSession(supabaseRefreshToken);
  });

  test(
    'joinEvent returns a response map',
    () async {
      final api = EdgeApi();
      final response = await api.joinEvent(joinToken);
      expect(response, isA<Map<String, dynamic>>());
    },
    skip: !(hasSupabaseEnv && joinToken.isNotEmpty)
        ? 'Set SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_REFRESH_TOKEN, '
            'and JOIN_EVENT_TOKEN to run.'
        : false,
  );

  test(
    'swipe returns a response map',
    () async {
      final api = EdgeApi();
      final response = await api.swipe(
        eventId: eventId,
        swipedId: swipedId,
        direction: direction,
      );
      expect(response, isA<Map<String, dynamic>>());
    },
    skip: !(hasSupabaseEnv && eventId.isNotEmpty && swipedId.isNotEmpty)
        ? 'Set SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_REFRESH_TOKEN, '
            'EVENT_ID, and SWIPED_ID to run.'
        : false,
  );
}
