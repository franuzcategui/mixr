import 'dart:convert';
import 'dart:io';

const _logPath = '/Users/franciscouzcategui/dev/mixr/.cursor/debug.log';
const _ingestUrl =
    'http://127.0.0.1:7242/ingest/7a87dc85-d280-4c72-ba44-8a739e152e1b';

void debugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
  String sessionId = 'debug-session',
  String runId = 'run1',
}) {
  final payload = {
    'id': 'log_${DateTime.now().millisecondsSinceEpoch}_$hypothesisId',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data,
    'sessionId': sessionId,
    'runId': runId,
    'hypothesisId': hypothesisId,
  };
  try {
    File(_logPath).writeAsStringSync(
      '${jsonEncode(payload)}\n',
      mode: FileMode.append,
    );
  } catch (_) {
    // Ignore file logging errors in debug instrumentation.
  }

  Future(() async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(_ingestUrl));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(payload));
      await request.close();
    } catch (_) {
      // Ignore HTTP logging errors in debug instrumentation.
    }
  });
}
