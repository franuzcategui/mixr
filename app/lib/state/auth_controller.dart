import 'dart:async';

import 'package:flutter/foundation.dart';
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
  AuthController(
    this._client, {
    this.onSignedOut,
    this.onSessionInvalid,
  }) : super(_buildSnapshot(_client.auth.currentSession)) {
    _subscription = _client.auth.onAuthStateChange.listen((data) {
      _handleAuthChange(data.event, data.session);
    });
  }

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _subscription;
  final VoidCallback? onSignedOut;
  final VoidCallback? onSessionInvalid;
  bool _isSigningOut = false;
  bool _isRefreshing = false;

  Future<void> _handleAuthChange(AuthChangeEvent event, Session? session) async {
    _logAuthEvent(event, session);
    final snapshot = _buildSnapshot(session);
    state = snapshot;

    if (event == AuthChangeEvent.signedOut) {
      onSignedOut?.call();
      return;
    }

    if (snapshot.isExpired) {
      await _refreshOrSignOut('session_expired');
      return;
    }

    if (event == AuthChangeEvent.userDeleted) {
      await _forceSignOut('user_deleted');
    }
  }

  void _logAuthEvent(AuthChangeEvent event, Session? session) {
    final token = session?.accessToken ?? '';
    final segments = token.isEmpty ? 0 : token.split('.').length;
    debugPrint(
      'Auth event: ${event.name}, user: ${session?.user.id ?? 'none'}, '
      'tokenSegments: $segments',
    );
  }

  Future<void> _refreshOrSignOut(String reason) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    debugPrint('Auth refresh attempt: $reason');
    try {
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session == null) {
        await _forceSignOut('refresh_failed');
      }
    } catch (error) {
      debugPrint('Auth refresh failed: $error');
      await _forceSignOut('refresh_failed');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _forceSignOut(String reason) async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    debugPrint('Auth forced sign-out: $reason');
    await _client.auth.signOut();
    onSessionInvalid?.call();
    _isSigningOut = false;
  }

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
