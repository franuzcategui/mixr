import 'package:flutter/material.dart';

import '../../domain/models/event.dart';

class MatchesPlaceholderScreen extends StatelessWidget {
  const MatchesPlaceholderScreen({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${event.name}'),
            const SizedBox(height: 12),
            const Text(
              'Matches will appear here during or after the swipe window.',
            ),
          ],
        ),
      ),
    );
  }
}
