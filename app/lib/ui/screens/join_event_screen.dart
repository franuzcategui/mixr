import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/api/edge_api.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_membership.dart';
import 'event_status_screen.dart';

class JoinEventScreen extends StatefulWidget {
  const JoinEventScreen({super.key});

  @override
  State<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends State<JoinEventScreen> {
  final _tokenController = TextEditingController();
  final _api = EdgeApi();
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
      final response = await _api.joinEvent(_tokenController.text.trim());
      final event = _eventFromResponse(response);
      final membership = EventMembership(
        eventId: event.id,
        userId: Supabase.instance.client.auth.currentUser?.id ?? 'me',
        joinedAt: DateTime.now(),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventStatusScreen(
            event: event,
            membership: membership,
            attendeeCount: 0,
          ),
        ),
      );
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
      final response = await _api.mintInvite();
      final inviteToken = response['invite_token'] as String?;
      if (inviteToken != null && inviteToken.isNotEmpty) {
        _tokenController.text = inviteToken;
      }
      setState(() {
        _errorMessage = 'Minted invite token.';
      });
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

  Map<String, dynamic>? _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(payload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  Event _eventFromResponse(Map<String, dynamic> response) {
    return Event(
      id: response['event_id'] as String,
      name: (response['event_name'] as String?) ?? 'Event',
      timezone: (response['timezone'] as String?) ?? 'UTC',
      swipeStartAt: DateTime.parse(response['swipe_start_at'] as String),
      swipeEndAt: DateTime.parse(response['swipe_end_at'] as String),
      isPaid: response['is_paid'] == true,
      isTestMode: response['is_test_mode'] == true,
      testModeAttendeeLimit:
          (response['test_mode_attendee_cap'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';
    final payload = token.isNotEmpty ? _decodeJwt(token) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Event')),
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
            // Text(
            //   'Debug:',
            //   style: Theme.of(context).textTheme.titleMedium,
            // ),
            const SizedBox(height: 8),
            // Text('Supabase URL: ${AppEnv.supabaseUrl}'),
            // Text('Session present: ${session != null}'),
            // Text('Token length: ${token.length}'),
            if (payload != null) ...[
              // Text('Token iss: ${payload['iss']}'),
              // Text('Token ref: ${payload['ref']}'),
              // Text('Token exp: ${payload['exp']}'),
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
          ],
        ),
      ),
    );
  }
}
