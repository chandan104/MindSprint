import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (unlocked && context.mounted) context.pop();
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
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      String? error;
      return StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Teacher PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Enter PIN'),
              ),
              if (error != null)
                Text(error!,
                    style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error)),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final valid =
                    await ref.read(pinServiceProvider).verify(controller.text);
                if (valid) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } else {
                  setState(() => error = 'Wrong PIN');
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  return result ?? false;
}
