import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_screen.dart';
import 'join_event_screen.dart';
import 'event_status_screen.dart';
import 'profile_setup_screen.dart';
import '../../state/providers.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.session == null) {
      return const AuthScreen();
    }

    final profile = ref.watch(profileControllerProvider);
    if (!profile.isComplete) {
      return const ProfileSetupScreen();
    }

    final event = ref.watch(eventControllerProvider).event;
    if (event == null) {
      return const JoinEventScreen();
    }

    return const EventStatusScreen();
  }
}
