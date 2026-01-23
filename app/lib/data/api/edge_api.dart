import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/api_exception.dart';

class EdgeApi {
  EdgeApi();

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
        } catch (error) {
          debugPrint('EdgeApi refreshSession failed: $error');
          await auth.signOut();
          throw ApiUnauthorizedException('Failed to refresh Supabase session.');
        }
      }
    }

    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw ApiUnauthorizedException('Missing Supabase access token.');
    }

    _logJwtClaims(accessToken);
    return accessToken;
  }

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
    Supabase.instance.client.functions.setAuth(accessToken);
    final segments = accessToken.split('.').length;
    debugPrint('EdgeApi $functionName token segments: $segments');

    try {
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: body,
      );
      final data = response.data;
      if (data == null) {
        return <String, dynamic>{};
      }
      if (data is Map<String, dynamic>) {
        return data;
      }
      return <String, dynamic>{'data': data};
    } on FunctionException catch (error) {
      debugPrint(
        'EdgeApi $functionName FunctionException: '
        'status=${error.status}, reason=${error.reasonPhrase}, '
        'details=${error.details}',
      );
      final message = _readErrorMessage(_stringifyFunctionError(error));
      if (error.status == 401) {
        debugPrint('EdgeApi $functionName 401 via functions client');
        await Supabase.instance.client.auth.signOut();
        throw ApiUnauthorizedException(message);
      }
      throw ApiServerException(message, statusCode: error.status);
    } catch (error) {
      debugPrint('EdgeApi $functionName unexpected error: $error');
      rethrow;
    }
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

  String _stringifyFunctionError(FunctionException error) {
    final details = error.details;
    if (details == null) {
      return error.reasonPhrase ?? 'Request failed.';
    }
    if (details is String) {
      return details;
    }
    try {
      return jsonEncode(details);
    } catch (_) {
      return details.toString();
    }
  }

  void _logJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      debugPrint('EdgeApi JWT has ${parts.length} segments (expected 3).');
      return;
    }
    final header = _decodeJwtPart(parts[0]);
    final payload = _decodeJwtPart(parts[1]);
    if (header == null || payload == null) {
      debugPrint('EdgeApi JWT decode failed.');
      return;
    }
    final now = DateTime.now().toUtc();
    final exp = _readUnixTimestamp(payload['exp']);
    final iat = _readUnixTimestamp(payload['iat']);
    debugPrint(
      'EdgeApi JWT header: alg=${header['alg']}, kid=${header['kid']}',
    );
    debugPrint(
      'EdgeApi JWT payload: iss=${payload['iss']}, aud=${payload['aud']}, '
      'sub=${payload['sub']}, iat=$iat, exp=$exp, now=$now',
    );
  }

  Map<String, dynamic>? _decodeJwtPart(String part) {
    try {
      final normalized = base64Url.normalize(part);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _readUnixTimestamp(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000, isUtc: true);
    }
    return null;
  }
}
