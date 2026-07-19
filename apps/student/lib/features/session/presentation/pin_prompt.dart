import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';

/// Modal PIN check used everywhere kiosk mode can be exited. Returns true
/// only when the stored teacher PIN is verified.
Future<bool> showTeacherPinPrompt(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _PinPromptDialog(),
  );
  return result ?? false;
}

/// Stateful so the TextEditingController lives exactly as long as the dialog
/// (disposing it earlier crashes the dialog's closing animation).
class _PinPromptDialog extends ConsumerStatefulWidget {
  const _PinPromptDialog();

  @override
  ConsumerState<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends ConsumerState<_PinPromptDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final valid = await ref.read(pinServiceProvider).verify(_controller.text);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Wrong PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Teacher PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Enter PIN'),
            onSubmitted: (_) => _unlock(),
          ),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _unlock, child: const Text('Unlock')),
      ],
    );
  }
}
