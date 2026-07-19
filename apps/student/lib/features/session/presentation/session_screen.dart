import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/timing/timing_service.dart';
import '../../assessments/domain/assessment_models.dart';
import '../../assessments/engine/assessment_module.dart';
import '../../assessments/engine/module_registry.dart';
import '../../assessments/engine/session_recorder.dart';
import '../../results/domain/provisional_metrics.dart';
import '../../results/presentation/result_screen.dart';
import '../domain/session_args.dart';
import 'pin_prompt.dart';

/// Runs one assessment session end-to-end:
///   mint session id → start monotonic clock → session_started →
///   module gameplay (module emits its own events) → terminal event →
///   provisional metrics from the local event log → result screen.
/// Kiosk-locked throughout; app lifecycle interruptions are recorded and
/// flag the session as interrupted (its timing is untrusted for benchmarks).
class SessionScreen extends ConsumerStatefulWidget {
  final SessionRunArgs args;
  const SessionScreen({super.key, required this.args});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with WidgetsBindingObserver {
  late final String _sessionId;
  late final TimingService _timing;
  late final SessionRecorder _recorder;
  bool _finished = false;
  bool _wasInterrupted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionId = const Uuid().v4();
    _timing = ref.read(timingServiceProvider);
    _recorder = SessionRecorder(
      sessionId: _sessionId,
      timing: _timing,
      store: DriftEventStore(ref.read(appDatabaseProvider)),
    );
    _timing.start();
    _recorder.recordAndFlush('session_started');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;
    // Reaction times spanning an interruption are meaningless; record the
    // fact and taint the session rather than pretending.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInterrupted = true;
      _recorder.recordAndFlush('app_backgrounded');
    } else if (state == AppLifecycleState.resumed && _wasInterrupted) {
      _recorder.recordAndFlush('app_foregrounded');
    }
  }

  Future<void> _onModuleFinished(AssessmentOutcome outcome) async {
    if (_finished) return;
    _finished = true;

    await _recorder.recordAndFlush(
      outcome == AssessmentOutcome.completed
          ? 'session_completed'
          : 'session_aborted',
      outcome == AssessmentOutcome.completed
          ? const {}
          : const {'reason': 'module_aborted'},
    );

    final rows =
        await ref.read(appDatabaseProvider).eventsForSession(_sessionId);
    final metrics = computeProvisionalMetrics([
      for (final row in rows)
        MetricEvent(eventType: row.eventType, tMs: row.tMs, payload: _decode(row.payloadJson)),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          student: widget.args.student,
          level: widget.args.level,
          metrics: metrics,
          wasInterrupted: _wasInterrupted,
        ),
      ),
    );
  }

  Future<void> _requestTeacherExit() async {
    final unlocked = await showTeacherPinPrompt(context);
    if (!unlocked || !mounted || _finished) return;
    _finished = true;
    await _recorder.recordAndFlush('session_aborted', {'reason': 'teacher_exit'});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final module = moduleForKey(widget.args.level.moduleKey);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestTeacherExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.args.student.studentName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _requestTeacherExit,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Teacher exit'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: module == null
                    ? Center(
                        child: Text(
                            'Module "${widget.args.level.moduleKey}" is not '
                            'available in this app version.'),
                      )
                    : module.buildRunner(AssessmentRunContext(
                        level: widget.args.level,
                        items: widget.args.items,
                        recorder: _recorder,
                        timing: _timing,
                        onFinished: _onModuleFinished,
                      )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, Object?> _decode(String payloadJson) {
  try {
    final decoded = SessionRecorder.decodePayload(payloadJson);
    return decoded;
  } catch (_) {
    return const {};
  }
}
