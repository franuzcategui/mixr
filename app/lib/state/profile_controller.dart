import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/profile_repo.dart';

class ProfileSnapshot {
  const ProfileSnapshot({
    required this.displayName,
    required this.bio,
    required this.status,
    required this.errorMessage,
  });

  final String displayName;
  final String? bio;
  final AsyncValue<void> status;
  final String? errorMessage;

  bool get isComplete => displayName.trim().isNotEmpty;

  ProfileSnapshot copyWith({
    String? displayName,
    String? bio,
    AsyncValue<void>? status,
    String? errorMessage,
  }) {
    return ProfileSnapshot(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  static const empty = ProfileSnapshot(
    displayName: '',
    bio: null,
    status: AsyncValue.data(null),
    errorMessage: null,
  );
}

class ProfileController extends StateNotifier<ProfileSnapshot> {
  ProfileController(this._repo) : super(ProfileSnapshot.empty);

  final ProfileRepo _repo;

  Future<void> loadMyProfile() async {
    state = state.copyWith(status: const AsyncValue.loading(), errorMessage: null);
    try {
      final profile = await _repo.fetchMyProfile();
      if (profile == null) {
        state = state.copyWith(status: const AsyncValue.data(null));
        return;
      }
      state = state.copyWith(
        displayName: profile['display_name'] as String? ?? '',
        bio: profile['bio'] as String?,
        status: const AsyncValue.data(null),
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        status: AsyncValue.error(error, stackTrace),
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> saveProfile({
    required String displayName,
    String? bio,
  }) async {
    if (displayName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Display name is required.');
      return;
    }
    state = state.copyWith(status: const AsyncValue.loading(), errorMessage: null);
    try {
      await _repo.upsertMyProfile(displayName: displayName, bio: bio);
      state = state.copyWith(
        displayName: displayName,
        bio: bio,
        status: const AsyncValue.data(null),
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        status: AsyncValue.error(error, stackTrace),
        errorMessage: error.toString(),
      );
    }
  }

  void clearProfile() {
    state = ProfileSnapshot.empty;
  }
}
