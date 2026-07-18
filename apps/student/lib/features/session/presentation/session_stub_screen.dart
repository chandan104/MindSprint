import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';

class SessionStubArgs {
  final String studentId;
  final String studentName;
  final String classId;

  const SessionStubArgs({
    required this.studentId,
    required this.studentName,
    required this.classId,
  });
}

/// Phase 1 stand-in for the assessment engine, with the REAL kiosk lock:
/// back navigation is trapped and leaving requires the teacher's PIN. The
/// assessment modules replace the body content in Phase 2; the lock stays.
class SessionStubScreen extends ConsumerWidget {
  final SessionStubArgs args;
  const SessionStubScreen({super.key, required this.args});

  Future<void> _requestExit(BuildContext context, WidgetRef ref) async {
    final unlocked = await _showPinPrompt(context, ref);
    // Imperative pop: PopScope(canPop: false) blocks system/back pops, but a
    // direct Navigator.pop after PIN verification is the sanctioned exit.
    if (unlocked && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit(context, ref);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        args.studentName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _requestExit(context, ref),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Teacher exit'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.extension_outlined,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Assessments arrive in Phase 2',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                        'This screen is kiosk-locked: leaving it requires the teacher PIN.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _showPinPrompt(BuildContext context, WidgetRef ref) async {
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
