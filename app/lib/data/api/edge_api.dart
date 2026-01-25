import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/debug/debug_log.dart';
import '../../core/errors/api_exception.dart';

class EdgeApi {
  EdgeApi(this._client);
  final SupabaseClient _client;


  Future<Map<String, dynamic>> joinEvent(String token) {
    return _invokeMap(
        'join_event',
      body: {'token': token},
    );
  }

  Future<Map<String, dynamic>> swipe({
    required String eventId,
    required String swipedId,
    required String direction,
  }) {
    return _invokeMap(
        'swipe',
      body: {
        'event_id': eventId,
        'swiped_id': swipedId,
        'direction': direction,
      },
    );
  }


  Future<Map<String, dynamic>> mintInvite() {
    return _invokeMap(
        'mint_invite',
      body: const {},
    );
  }

  Future<Map<String, dynamic>> _invokeMap(
  String functionName, {
  required Map<String, dynamic> body,
}) async {
  final session = _client.auth.currentSession;
  if (session == null) {
    throw ApiUnauthorizedException('Not signed in.');
  }

  // Safe debug (no secrets)
  final token = session.accessToken;
  debugPrint('[EdgeApi] invoke=$functionName tokenLen=${token.length} segments=${token.split(".").length}');

  // #region agent log
  debugLog(
    hypothesisId: 'H1',
    location: 'edge_api.dart:_invokeMap',
    message: 'Invoke function start',
    data: {
      'function': functionName,
      'hasSession': true,
      'expiresAt': session.expiresAt,
      'tokenSegments': token.split('.').length,
    },
  );
  // #endregion

  try {
    final res = await _client.functions.invoke(functionName, body: body);

    // Some SDK versions expose status; some don’t. Guard it.
    final status = (res as dynamic).status as int?;
    if (status != null && (status < 200 || status >= 300)) {
      final msg = _extractMessage(res.data) ?? 'Function failed';
      if (status == 401) throw ApiUnauthorizedException(msg);
      throw ApiServerException(msg, statusCode: status);
    }

    final data = res.data;
    // #region agent log
    debugLog(
      hypothesisId: 'H1',
      location: 'edge_api.dart:_invokeMap',
      message: 'Invoke function success',
      data: {
        'function': functionName,
        'status': status,
        'hasData': data != null,
      },
    );
    // #endregion
    if (data == null) return <String, dynamic>{};
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'data': data};
  } on FunctionException catch (e) {
    // #region agent log
    debugLog(
      hypothesisId: 'H3',
      location: 'edge_api.dart:_invokeMap',
      message: 'Invoke function error',
      data: {
        'function': functionName,
        'status': e.status,
        'reason': e.reasonPhrase,
        'hasDetails': e.details != null,
      },
    );
    // #endregion
    final msg = e.details?['message']?.toString()
        ?? e.reasonPhrase
        ?? 'Function error';
    if (e.status == 401) throw ApiUnauthorizedException(msg);
    throw ApiServerException(msg, statusCode: e.status);
  }
}

String? _extractMessage(dynamic data) {
  if (data == null) return null;
  if (data is String) return data;
  if (data is Map) {
    final m = data['message'] ?? data['error'] ?? data['msg'];
    return m?.toString();
  }
  return data.toString();
}


// Future<Map<String, dynamic>> _invokeMap(
//     String functionName, {
//     required Map<String, dynamic> body,
//   }) async {

//     // check if the user is signed in
//      try {
//       if (Supabase.instance.client.auth.currentSession == null) {
//         throw StateError('Please sign in to join an event.');
//       }
//       // get the access token for debugggin
//       final session = Supabase.instance.client.auth.currentSession;
//       debugPrint('JoinEvent access token: ${session?.accessToken ?? '(none)'}');
//     } catch (e) {
//       debugPrint('EdgeApi _invokeMap error: $e');
//       throw ApiUnauthorizedException(e.toString());
//     }
    
//     try {
//       final res = await _client.functions.invoke(
//         functionName,
//         body: body,
//       );
      

//       // Depending on SDK version, errors may appear as `error` or as an exception.
//       // If this compiles with your version, keep it; otherwise rely on the catch below.
//       if (res.status != 200) {
//         debugPrint('EdgeApi _invokeMap error: ${res.data} token: ${body['token']}');
//         final msg = res.data as String;
//         // Some SDKs provide status; if yours does, map 401 cleanly.
//         throw ApiServerException(msg);
//       }

//       final data = res.data;
//       if (data == null) return <String, dynamic>{};

//       if (data is Map) {
//         return Map<String, dynamic>.from(data);
//       }

//       // Normalize non-map responses
//       return <String, dynamic>{'data': data};
//     } on FunctionException catch (e) {
//       // This is what you’ve been seeing: status=401, message=Invalid JWT
//       if (e.status == 401) {
//         throw ApiUnauthorizedException(e.details?['message']?.toString() ?? e.reasonPhrase ?? 'Unauthorized');
//       }
//       throw ApiServerException(
//         e.details?['message']?.toString() ?? e.reasonPhrase ?? e.toString(),
//         statusCode: e.status,
//       );
//     } catch (e) {
//       // Keep a sane fallback
//       throw ApiServerException(e.toString());
//     }
//   }
}
