import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/api/edge_api.dart';
import '../data/repositories/profile_repo.dart';
import '../data/repositories/swipe_repo.dart';
import 'auth_controller.dart';
import 'event_controller.dart';
import 'profile_controller.dart';
import 'swipe_controller.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final edgeApiProvider = Provider<EdgeApi>(
  (ref) => EdgeApi(),
);

final swipeRepoProvider = Provider<SwipeRepo>(
  (ref) => SwipeRepo(ref.watch(supabaseClientProvider)),
);

final profileRepoProvider = Provider<ProfileRepo>(
  (ref) => ProfileRepo(ref.watch(supabaseClientProvider)),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSnapshot>(
  (ref) => AuthController(
    ref.watch(supabaseClientProvider),
    onSignedOut: () => ref.read(authCleanupProvider).clearLocalState(),
    onSessionInvalid: () => ref.read(authCleanupProvider).clearLocalState(),
  ),
);

final eventControllerProvider =
    StateNotifierProvider<EventController, EventStateSnapshot>(
  (ref) => EventController(ref.watch(edgeApiProvider)),
);

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileSnapshot>(
  (ref) => ProfileController(ref.watch(profileRepoProvider)),
);

final swipeControllerProvider =
    StateNotifierProvider<SwipeController, SwipeStateSnapshot>(
  (ref) => SwipeController(
    ref.watch(swipeRepoProvider),
    ref.watch(edgeApiProvider),
    ref,
  ),
);

final authCleanupProvider = Provider<AuthCleanup>(
  (ref) => AuthCleanup(ref),
);

class AuthCleanup {
  AuthCleanup(this._ref);

  final Ref _ref;

  void clearLocalState() {
    _ref.read(eventControllerProvider.notifier).clearEvent();
    _ref.read(profileControllerProvider.notifier).clearProfile();
    _ref.read(swipeControllerProvider.notifier).clearSwipe();
  }

  Future<void> signOutAndClear() async {
    await _ref.read(supabaseClientProvider).auth.signOut();
    clearLocalState();
  }

  Future<void> hardResetAuth() async {
    await _ref.read(supabaseClientProvider).auth.signOut();
    clearLocalState();
  }
}
