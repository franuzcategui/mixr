import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class SwipePlaceholderScreen extends ConsumerStatefulWidget {
  const SwipePlaceholderScreen({super.key});

  @override
  ConsumerState<SwipePlaceholderScreen> createState() =>
      _SwipePlaceholderScreenState();
}

class _SwipePlaceholderScreenState extends ConsumerState<SwipePlaceholderScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      Future.microtask(
        () => ref.read(swipeControllerProvider.notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(swipeControllerProvider, (previous, next) {
      if (next.lastMatchUserId != null &&
          next.lastMatchUserId != previous?.lastMatchUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matched!')),
        );
      }
    });

    final state = ref.watch(swipeControllerProvider);
    final card = ref.read(swipeControllerProvider.notifier).currentCard;

    return Scaffold(
      appBar: AppBar(title: const Text('Swipe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.status.isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            if (card == null)
              const Text('No more candidates.'),
            if (card != null) ...[
              Text(card.displayName, style: Theme.of(context).textTheme.titleLarge),
              if (card.bio != null) ...[
                const SizedBox(height: 8),
                Text(card.bio!),
              ],
              const SizedBox(height: 12),
              if (card.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    card.photoUrls.first,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 220,
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: const Text('No photo'),
                ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: card == null
                        ? null
                        : () => ref
                            .read(swipeControllerProvider.notifier)
                            .swipeLeft(),
                    child: const Text('Left'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: card == null
                        ? null
                        : () => ref
                            .read(swipeControllerProvider.notifier)
                            .swipeRight(),
                    child: const Text('Right'),
                  ),
                ),
              ],
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
