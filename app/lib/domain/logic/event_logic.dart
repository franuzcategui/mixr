import '../models/event.dart';
import '../models/event_membership.dart';
import 'event_state.dart';

EventState computeEventState(Event event, DateTime now, bool isUnlocked) {
  if (!event.isPaid && !event.isTestMode) {
    return EventState.draft;
  }

  if (now.isBefore(event.swipeStartAt)) {
    return isUnlocked ? EventState.countdown : EventState.locked;
  }

  if (!now.isBefore(event.swipeEndAt)) {
    return EventState.ended;
  }

  return isUnlocked ? EventState.live : EventState.locked;
}

bool canSwipe(
  Event event,
  EventMembership me,
  int attendeeCount,
  DateTime now,
) {
  if (me.eventId != event.id) {
    return false;
  }

  if (now.isBefore(event.swipeStartAt) || !now.isBefore(event.swipeEndAt)) {
    return false;
  }

  final isUnlocked = event.isPaid ||
      (event.isTestMode && attendeeCount <= event.testModeAttendeeLimit);

  return isUnlocked;
}
