import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/event_logic.dart';
import '../../domain/logic/event_state.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_membership.dart';
import '../../state/providers.dart';
import 'matches_placeholder_screen.dart';
import 'swipe_placeholder_screen.dart';

class EventStatusScreen extends ConsumerStatefulWidget {
  const EventStatusScreen({super.key});

  @override
  ConsumerState<EventStatusScreen> createState() => _EventStatusScreenState();
}

class _EventStatusScreenState extends ConsumerState<EventStatusScreen> {
  late final TextEditingController _attendeeCountController;
  late int _attendeeCount;

  @override
  void initState() {
    super.initState();
    _attendeeCount = 0;
    _attendeeCountController =
        TextEditingController(text: _attendeeCount.toString());
  }

  @override
  void dispose() {
    _attendeeCountController.dispose();
    super.dispose();
  }

  void _updateAttendeeCount(String value) {
    final parsed = int.tryParse(value) ?? _attendeeCount;
    setState(() {
      _attendeeCount = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(eventControllerProvider).event;
    if (snapshot == null) {
      return const Scaffold(
        body: Center(child: Text('No event loaded.')),
      );
    }

    final event = Event(
      id: snapshot.eventId,
      name: snapshot.eventName,
      timezone: snapshot.timezone,
      swipeStartAt: DateTime.parse(snapshot.swipeStartAt).toUtc(),
      swipeEndAt: DateTime.parse(snapshot.swipeEndAt).toUtc(),
      isPaid: snapshot.isPaid,
      isTestMode: snapshot.isTestMode,
      testModeAttendeeLimit: snapshot.testModeAttendeeCap,
    );
    final session = ref.read(authControllerProvider).session;
    final userId = session == null ? 'me' : session.user.id;
    final membership = EventMembership(
      eventId: event.id,
      userId: userId,
      joinedAt: DateTime.now().toUtc(),
    );

    final now = DateTime.now().toUtc();
    print('now: $now');
    final isUnlocked = event.isPaid ||
        (event.isTestMode && _attendeeCount <= event.testModeAttendeeLimit);
    final state = computeEventState(event, now, isUnlocked);
    final swipeAllowed = canSwipe(
      event,
      membership,
      _attendeeCount,
      now,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              ref.read(eventControllerProvider.notifier).clearEvent();
              ref.read(profileControllerProvider.notifier).clearProfile();
              ref.read(swipeControllerProvider.notifier).clearSwipe();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Event status: ${_labelForState(state)}'),
            const SizedBox(height: 8),
            Text('Timezone: ${event.timezone}'),
            const SizedBox(height: 8),
            Text('Swipe window: ${event.swipeStartAt} → ${event.swipeEndAt}'),
            const SizedBox(height: 8),
            Text('Unlocked: ${isUnlocked ? 'yes' : 'no'}'),
            const SizedBox(height: 16),
            TextField(
              controller: _attendeeCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Attendee count',
                border: OutlineInputBorder(),
              ),
              onChanged: _updateAttendeeCount,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: swipeAllowed
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SwipePlaceholderScreen(),
                        ),
                      );
                    }
                  : null,
              child: const Text('Open Swipe'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchesPlaceholderScreen(
                      event: event,
                    ),
                  ),
                );
              },
              child: const Text('Open Matches'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {}),
              child: const Text('Refresh status'),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForState(EventState state) {
    switch (state) {
      case EventState.draft:
        return 'Draft (payment required)';
      case EventState.locked:
        return 'Locked (not unlocked)';
      case EventState.countdown:
        return 'Countdown (before swipe window)';
      case EventState.live:
        return 'Live (swiping open)';
      case EventState.ended:
        return 'Ended (swiping closed)';
    }
  }
}
