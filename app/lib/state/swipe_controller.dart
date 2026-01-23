import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/api/edge_api.dart';
import '../data/repositories/swipe_repo.dart';
import '../domain/models/user_card.dart';
import 'providers.dart';

class SwipeStateSnapshot {
  const SwipeStateSnapshot({
    required this.candidates,
    required this.currentIndex,
    required this.status,
    required this.errorMessage,
    required this.lastMatchUserId,
  });

  final List<UserCard> candidates;
  final int currentIndex;
  final AsyncValue<void> status;
  final String? errorMessage;
  final String? lastMatchUserId;

  SwipeStateSnapshot copyWith({
    List<UserCard>? candidates,
    int? currentIndex,
    AsyncValue<void>? status,
    String? errorMessage,
    String? lastMatchUserId,
  }) {
    return SwipeStateSnapshot(
      candidates: candidates ?? this.candidates,
      currentIndex: currentIndex ?? this.currentIndex,
      status: status ?? this.status,
      errorMessage: errorMessage,
      lastMatchUserId: lastMatchUserId ?? this.lastMatchUserId,
    );
  }

  static const empty = SwipeStateSnapshot(
    candidates: [],
    currentIndex: 0,
    status: AsyncValue.data(null),
    errorMessage: null,
    lastMatchUserId: null,
  );
}

class SwipeController extends StateNotifier<SwipeStateSnapshot> {
  SwipeController(this._repo, this._api, this._ref)
      : super(SwipeStateSnapshot.empty);

  final SwipeRepo _repo;
  final EdgeApi _api;
  final Ref _ref;
  bool _isLoading = false;
  bool _isSwiping = false;

  UserCard? get currentCard =>
      state.currentIndex < state.candidates.length
          ? state.candidates[state.currentIndex]
          : null;

  bool get hasMore => state.currentIndex < state.candidates.length;

  Future<void> load() async {
    if (_isLoading) return;
    final event = _ref.read(eventControllerProvider).event;
    if (event == null) {
      state = state.copyWith(errorMessage: 'No event selected.');
      return;
    }

    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      state = state.copyWith(errorMessage: 'Please sign in again.');
      return;
    }

    _isLoading = true;
    state = state.copyWith(status: const AsyncValue.loading(), errorMessage: null);
    try {
      final candidates = await _repo.fetchCandidates(
        eventId: event.eventId,
        currentUserId: currentUserId,
      );
      state = state.copyWith(
        candidates: candidates,
        currentIndex: 0,
        status: const AsyncValue.data(null),
        lastMatchUserId: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        status: AsyncValue.error(error, stackTrace),
        errorMessage: error.toString(),
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<void> swipeLeft() => _swipe('left');

  Future<void> swipeRight() => _swipe('right');

  void clearSwipe() {
    _isLoading = false;
    _isSwiping = false;
    state = SwipeStateSnapshot.empty;
  }

  Future<void> _swipe(String direction) async {
    if (_isSwiping) return;
    final event = _ref.read(eventControllerProvider).event;
    if (event == null) {
      state = state.copyWith(errorMessage: 'No event selected.');
      return;
    }

    final card = currentCard;
    if (card == null) return;

    _isSwiping = true;
    final previousIndex = state.currentIndex;
    state = state.copyWith(
      currentIndex: previousIndex + 1,
      status: const AsyncValue.loading(),
      errorMessage: null,
      lastMatchUserId: null,
    );

    try {
      final response = await _api.swipe(
        eventId: event.eventId,
        swipedId: card.userId,
        direction: direction,
      );
      final matched = response['matched'] == true;
      if (matched) {
        state = state.copyWith(
          status: const AsyncValue.data(null),
          lastMatchUserId: card.userId,
        );
      } else if (response['already_swiped'] == true) {
        state = state.copyWith(status: const AsyncValue.data(null));
      } else {
        state = state.copyWith(status: const AsyncValue.data(null));
      }
    } catch (error) {
      final message = error.toString();
      if (message.contains('EVENT_LOCKED') ||
          message.contains('OUTSIDE_WINDOW')) {
        state = state.copyWith(
          currentIndex: previousIndex,
          status: const AsyncValue.data(null),
          errorMessage:
              'Swiping is locked right now. Try again during the swipe window.',
        );
      } else if (message.contains('already_swiped')) {
        state = state.copyWith(status: const AsyncValue.data(null));
      } else {
        state = state.copyWith(
          status: AsyncValue.error(error, StackTrace.current),
          errorMessage: message,
        );
      }
    } finally {
      _isSwiping = false;
    }
  }
}
