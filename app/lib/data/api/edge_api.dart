import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/api_exception.dart';

class EdgeApi {
  EdgeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> joinEvent(String token) {
    return _postJson(
      functionName: 'join_event',
      body: {'token': token},
    );
  }

  Future<Map<String, dynamic>> swipe({
    required String eventId,
    required String swipedId,
    required String direction,
  }) {
    return _postJson(
      functionName: 'swipe',
      body: {
        'event_id': eventId,
        'swiped_id': swipedId,
        'direction': direction,
      },
    );
  }

  Future<Map<String, dynamic>> mintInvite() {
    return _postJson(
      functionName: 'mint_invite',
      body: const {},
    );
  }

  Future<Map<String, dynamic>> _postJson({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    final accessToken = await _resolveAccessToken();

    final uri = Uri.parse('${AppEnv.supabaseUrl}/functions/v1/$functionName');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'apikey': AppEnv.supabaseAnonKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _readErrorMessage(response.body);
      if (response.statusCode == 401) {
        throw ApiUnauthorizedException(message);
      }
      throw ApiServerException(message, statusCode: response.statusCode);
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  Future<String> _resolveAccessToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) {
      throw ApiUnauthorizedException('Missing Supabase access token.');
    }

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 1)))) {
        try {
          final refreshed = await auth.refreshSession();
          session = refreshed.session ?? auth.currentSession;
        } catch (_) {
          throw ApiUnauthorizedException('Failed to refresh Supabase session.');
        }
      }
    }

    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw ApiUnauthorizedException('Missing Supabase access token.');
    }

    return accessToken;
  }

  String _readErrorMessage(String body) {
    if (body.isEmpty) {
      return 'Request failed with no response body.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
