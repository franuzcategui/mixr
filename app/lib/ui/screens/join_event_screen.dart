import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../../core/debug/debug_log.dart';
import '../../domain/models/event.dart';
import '../../state/providers.dart';
import 'event_status_screen.dart';

class JoinEventScreen extends ConsumerStatefulWidget {
  const JoinEventScreen({super.key});

  @override
  ConsumerState<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends ConsumerState<JoinEventScreen> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _joinEvent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        throw StateError('Please sign in to join an event.');
      }
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('JoinEvent access token: ${session?.accessToken ?? '(none)'}');
      await ref
          .read(eventControllerProvider.notifier)
          .joinEvent(_tokenController.text.trim());

      final state = ref.read(eventControllerProvider);
      if (state.event != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const EventStatusScreen(),
          ),
        );
      } else if (state.errorMessage != null) {
        setState(() {
          _errorMessage = state.errorMessage;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _mintInvite() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // #region agent log
      final session = Supabase.instance.client.auth.currentSession;
      debugLog(
        hypothesisId: 'H2 llego aqui paps',
        location: 'join_event_screen.dart:_mintInvite',
        message: 'Mint invite invoked',
        data: {
          'hasSession': session != null,
          'expiresAt': session?.expiresAt,
          'tokenSegments': session?.accessToken.isNotEmpty == true
              ? session!.accessToken.split('.').length
              : 0,
        },
      );
      // #endregion

      final response = await ref.read(edgeApiProvider).mintInvite();
      final inviteToken = response['invite_token'] as String?;
      if (inviteToken != null && inviteToken.isNotEmpty) {
        _tokenController.text = inviteToken;
      }
      // #region agent log
      debugLog(
        hypothesisId: 'H2',
        location: 'join_event_screen.dart:_mintInvite',
        message: 'Mint invite success',
        data: {'hasInviteToken': inviteToken?.isNotEmpty == true},
      );
      // #endregion
      setState(() {
        _errorMessage = 'Minted invite token.';
      });
    } catch (error) {
      // #region agent log
      debugLog(
        hypothesisId: 'H2',
        location: 'join_event_screen.dart:_mintInvite',
        message: 'Mint invite error',
        data: {'error': error.toString()},
      );
      // #endregion
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  

  Map<String, dynamic>? _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(payload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';
    final payload = token.isNotEmpty ? _decodeJwt(token) : null;
    final eventState = ref.watch(eventControllerProvider);
    final event = eventState.event;
    final domainEvent = event == null
        ? null
        : Event(
            id: event.eventId,
            name: event.eventName,
            timezone: event.timezone,
            swipeStartAt: DateTime.parse(event.swipeStartAt).toUtc(),
            swipeEndAt: DateTime.parse(event.swipeEndAt).toUtc(),
            isPaid: event.isPaid,
            isTestMode: event.isTestMode,
            testModeAttendeeLimit: event.testModeAttendeeCap,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authCleanupProvider).signOutAndClear();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Invite token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _joinEvent,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Event'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _mintInvite,
              child: const Text('Mint test invite'),
            ),
            const SizedBox(height: 16),
            Text(
              'Debug:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Supabase URL: ${AppEnv.supabaseUrl}'),
            Text('Session present: ${session != null}'),
            Text('Token length: ${token.length}'),
            if (payload != null) ...[
              Text('Token iss: ${payload['iss']}'),
              Text('Token ref: ${payload['ref']}'),
              Text('Token exp: ${payload['exp']}'),
            ],
            const SizedBox(height: 8),
            // Text('Access token: ${token.isEmpty ? '(none)' : token}'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: token.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: token));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Access token copied')),
                      );
                    },
              child: const Text('Copy access token'),
            ),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (domainEvent != null) ...[
              const SizedBox(height: 12),
              Text(
                'Joined event: ${domainEvent.name}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
