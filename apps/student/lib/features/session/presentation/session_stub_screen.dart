import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/timing/timing_service.dart';
import '../../assessments/engine/session_recorder.dart';
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

/// Phase 1 stand-in for the assessment engine that already runs the REAL
/// measurement pipeline: a session id is minted, the monotonic TimingService
/// starts, and session_started / session_aborted events are recorded to the
/// local Drift store. Assessment modules replace the body in Phase 2; the
/// kiosk lock (trapped back navigation, PIN-gated exit) stays.
class SessionStubScreen extends ConsumerStatefulWidget {
  final SessionStubArgs args;
  const SessionStubScreen({super.key, required this.args});

  @override
  ConsumerState<SessionStubScreen> createState() => _SessionStubScreenState();
}

class _SessionStubScreenState extends ConsumerState<SessionStubScreen> {
  late final String _sessionId;
  late final TimingService _timing;
  late final SessionRecorder _recorder;
  Timer? _ticker;
  int _elapsedMs = 0;

  @visibleForTesting
  String get debugSessionIdForTest => _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _timing = ref.read(timingServiceProvider);
    _recorder = SessionRecorder(
      sessionId: _sessionId,
      timing: _timing,
      store: DriftEventStore(ref.read(appDatabaseProvider)),
    );
    _timing.start();
    _recorder.recordAndFlush('session_started');
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _elapsedMs = _timing.nowMs);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _requestExit() async {
    final unlocked = await _showPinPrompt(context, ref);
    if (!unlocked || !mounted) return;
    // Phase 1 sessions are always aborted (no assessment to complete yet).
    await _recorder.recordAndFlush('session_aborted', {'reason': 'teacher_exit'});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_elapsedMs / 1000).toStringAsFixed(1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
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
                        widget.args.studentName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _requestExit,
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
                      const SizedBox(height: 32),
                      Text('Session clock: ${seconds}s',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        'Events recorded locally: ${_recorder.nextSeq - 1}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Session ${_sessionId.substring(0, 8)}…',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
