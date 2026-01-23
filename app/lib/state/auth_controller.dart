import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSnapshot {
  const AuthSnapshot({
    required this.session,
    required this.isExpired,
  });

  final Session? session;
  final bool isExpired;

  static const empty = AuthSnapshot(session: null, isExpired: false);
}

class AuthController extends StateNotifier<AuthSnapshot> {
  AuthController(this._client) : super(_buildSnapshot(_client.auth.currentSession)) {
    _subscription = _client.auth.onAuthStateChange.listen((data) {
      final snapshot = _buildSnapshot(data.session);
      state = snapshot;
      if (snapshot.isExpired) {
        signOut();
      }
    });
  }

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _subscription;

  static AuthSnapshot _buildSnapshot(Session? session) {
    if (session == null) {
      return AuthSnapshot.empty;
    }
    final expiresAt = session.expiresAt;
    final isExpired = expiresAt != null &&
        DateTime.now()
            .isAfter(DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000));
    return AuthSnapshot(session: session, isExpired: isExpired);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = AuthSnapshot.empty;
  }
}
