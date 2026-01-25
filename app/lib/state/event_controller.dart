import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/edge_api.dart';

class EventSnapshot {
  const EventSnapshot({
    required this.eventId,
    required this.eventName,
    required this.swipeStartAt,
    required this.swipeEndAt,
    required this.timezone,
    required this.isPaid,
    required this.isTestMode,
    required this.testModeAttendeeCap,
  });

  final String eventId;
  final String eventName;
  final String swipeStartAt;
  final String swipeEndAt;
  final String timezone;
  final bool isPaid;
  final bool isTestMode;
  final int testModeAttendeeCap;
}

class EventStateSnapshot {
  const EventStateSnapshot({
    required this.event,
    required this.status,
    this.errorMessage,
  });

  final EventSnapshot? event;
  final AsyncValue<void> status;
  final String? errorMessage;

  EventStateSnapshot copyWith({
    EventSnapshot? event,
    AsyncValue<void>? status,
    String? errorMessage,
  }) {
    return EventStateSnapshot(
      event: event ?? this.event,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  static const empty = EventStateSnapshot(
    event: null,
    status: AsyncValue.data(null),
    errorMessage: null,
  );
}

class EventController extends StateNotifier<EventStateSnapshot> {
  EventController(this._api) : super(EventStateSnapshot.empty);

  final EdgeApi _api;

  Future<void> joinEvent(String token) async {
    if (token.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Invite token is required.');
      return;
    }

    state = state.copyWith(status: const AsyncValue.loading(), errorMessage: null);
    try {
      final response = await _api.joinEvent(token);
      final event = EventSnapshot(
        eventId: response['event_id'] as String,
        eventName: (response['event_name'] as String?) ?? 'Event',
        swipeStartAt: response['swipe_start_at'] as String,
        swipeEndAt: response['swipe_end_at'] as String,
        timezone: (response['timezone'] as String?) ?? 'UTC',
        isPaid: response['is_paid'] == true,
        isTestMode: response['is_test_mode'] == true,
        testModeAttendeeCap:
            (response['test_mode_attendee_cap'] as num?)?.toInt() ?? 0,
      );
      state = state.copyWith(
        event: event,
        status: const AsyncValue.data(null),
      );
    } catch (error) {
      state = state.copyWith(
        status: AsyncValue.error(error, StackTrace.current),
        errorMessage: error.toString(),
      );
    }
  }

    Future<void> mintInvite(String token) async {
 
    state = state.copyWith(status: const AsyncValue.loading(), errorMessage: null);
    try {
      final response = await _api.mintInvite();
      final event = EventSnapshot(
        eventId: response['event_id'] as String,
        eventName: (response['event_name'] as String?) ?? 'Event',
        swipeStartAt: response['swipe_start_at'] as String,
        swipeEndAt: response['swipe_end_at'] as String,
        timezone: (response['timezone'] as String?) ?? 'UTC',
        isPaid: response['is_paid'] == true,
        isTestMode: response['is_test_mode'] == true,
        testModeAttendeeCap:
            (response['test_mode_attendee_cap'] as num?)?.toInt() ?? 0,
      );
      state = state.copyWith(
        event: event,
        status: const AsyncValue.data(null),
      );
    } catch (error) {
      state = state.copyWith(
        status: AsyncValue.error(error, StackTrace.current),
        errorMessage: error.toString(),
      );
    }
  }

  void clearEvent() {
    state = EventStateSnapshot.empty;
  }
}
