import 'dart:convert';
import 'dart:io';

const _logPath = '/Users/franciscouzcategui/dev/mixr/.cursor/debug.log';

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
    // Ignore logging errors in debug instrumentation.
  }
}
