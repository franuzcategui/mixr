import 'package:flutter/material.dart';

import '../../data/api/edge_api.dart';
import '../../domain/models/event.dart';

class SwipePlaceholderScreen extends StatefulWidget {
  const SwipePlaceholderScreen({super.key, required this.event});

  final Event event;

  @override
  State<SwipePlaceholderScreen> createState() => _SwipePlaceholderScreenState();
}

class _SwipePlaceholderScreenState extends State<SwipePlaceholderScreen> {
  final _swipedIdController = TextEditingController();
  final _api = EdgeApi();
  bool _isLoading = false;
  String _direction = 'right';
  String? _message;

  @override
  void dispose() {
    _swipedIdController.dispose();
    super.dispose();
  }

  Future<void> _sendSwipe() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final response = await _api.swipe(
        eventId: widget.event.id,
        swipedId: _swipedIdController.text.trim(),
        direction: _direction,
      );
      setState(() {
        _message = 'Swipe sent: ${response.toString()}';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swipe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Event: ${widget.event.name}'),
            const SizedBox(height: 12),
            TextField(
              controller: _swipedIdController,
              decoration: const InputDecoration(
                labelText: 'Swiped user id',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _direction,
              decoration: const InputDecoration(
                labelText: 'Direction',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'left', child: Text('Left')),
                DropdownMenuItem(value: 'right', child: Text('Right')),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _direction = value ?? 'right'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _sendSwipe,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send swipe'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}
