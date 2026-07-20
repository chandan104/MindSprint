import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../core/widgets/countdown_bar.dart';
import '../domain/assessment_models.dart';
import '../engine/assessment_module.dart';
import '../widgets/item_visual.dart';

class FocusTapModule implements AssessmentModule {
  @override
  String get moduleKey => 'attention_focus';

  @override
  String get displayName => 'Focus Tap';

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      FocusTapRunner(runContext: context);
}

/// Config knobs (contracts/levels/v1/attention_focus.config.json).
class _Config {
  final int stimulusCount;
  final double targetRatio;
  final int displayTimeMs;
  final int interStimulusGapMs;

  _Config(Map<String, Object?> raw)
      : stimulusCount = raw['stimulus_count'] as int,
        targetRatio = (raw['target_ratio'] as num).toDouble(),
        displayTimeMs = raw['display_time_ms'] as int,
        interStimulusGapMs = raw['inter_stimulus_gap_ms'] as int;
}

class _Stimulus {
  final ContentItem item;
  final bool isTarget;
  const _Stimulus(this.item, this.isTarget);
}

enum _Phase { ready, stimulus, gap }

/// Go/no-go (Verdant Core world): one designated target; a stream of items
/// appears one at a time. Tap the target, withhold for everything else.
/// Event contract (defined by attention_focus_basic.json, fixture-first):
/// exactly one response event per stimulus — a tap_registered (hit or
/// commission), or on window expiry an answer_submitted 'miss' (omission,
/// incorrect) / 'pass' (correct rejection, correct). The stream never waits
/// for the child; that pressure is the measurement.
class FocusTapRunner extends StatefulWidget {
  final AssessmentRunContext runContext;
  final Random? random;

  const FocusTapRunner({super.key, required this.runContext, this.random});

  @override
  State<FocusTapRunner> createState() => _FocusTapRunnerState();
}

class _FocusTapRunnerState extends State<FocusTapRunner> {
  late final _Config _config;
  late final Random _rng;
  late final ContentItem _target;
  late final List<_Stimulus> _stimuli;

  _Phase _phase = _Phase.ready;
  int _index = -1;
  bool _responded = false;
  bool? _lastTapCorrect;
  Timer? _timer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('attention_focus');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _rng = widget.random ?? Random();

    final pool = [..._run.items]..shuffle(_rng);
    _target = pool.first;
    final distractors = pool.skip(1).toList();

    // Guarantee at least one target and one distractor regardless of ratio.
    final targetCount = min(_config.stimulusCount - 1,
        max(1, (_config.stimulusCount * _config.targetRatio).round()));
    final plan = <_Stimulus>[
      for (var i = 0; i < targetCount; i++) _Stimulus(_target, true),
      for (var i = 0; i < _config.stimulusCount - targetCount; i++)
        _Stimulus(distractors[_rng.nextInt(distractors.length)], false),
    ]..shuffle(_rng);
    _stimuli = plan;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    if (_index + 1 >= _stimuli.length) {
      _run.onFinished(AssessmentOutcome.completed);
      return;
    }
    setState(() {
      _index++;
      _responded = false;
      _lastTapCorrect = null;
      _phase = _Phase.stimulus;
    });
    final stimulus = _stimuli[_index];
    _run.recorder.record('item_displayed', {
      'item_id': stimulus.item.id,
      'label': stimulus.item.label,
      'position_index': _index,
      'is_target': stimulus.isTarget,
    });
    _timer = Timer(Duration(milliseconds: _config.displayTimeMs), _closeWindow);
  }

  void _closeWindow() {
    if (!mounted) return;
    if (!_responded) {
      final stimulus = _stimuli[_index];
      // Silent measurement: an omission is never announced to the child.
      _run.recorder.record('answer_submitted', {
        'answer': stimulus.isTarget ? 'miss' : 'pass',
        'is_correct': !stimulus.isTarget,
      });
    }
    setState(() => _phase = _Phase.gap);
    _timer =
        Timer(Duration(milliseconds: _config.interStimulusGapMs), _advance);
  }

  void _onStimulusTap(TapDownDetails details) {
    if (_phase != _Phase.stimulus || _responded) return;
    final stimulus = _stimuli[_index];
    _responded = true;
    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': stimulus.item.id,
      'label': stimulus.item.label,
      'is_correct': stimulus.isTarget,
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    });
    setState(() => _lastTapCorrect = stimulus.isTarget);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          identity: _identity,
          target: _target,
          progress: _index + 1,
          total: _stimuli.length,
          started: _phase != _Phase.ready,
        ),
        Expanded(
          child: switch (_phase) {
            _Phase.ready => _ReadyView(
                identity: _identity,
                target: _target,
                onStart: _advance,
              ),
            _Phase.stimulus => _StimulusView(
                key: ValueKey('stimulus-$_index'),
                stimulus: _stimuli[_index],
                displayMs: _config.displayTimeMs,
                tapCorrect: _lastTapCorrect,
                accent: _identity.accent,
                onTapDown: _onStimulusTap,
              ),
            _Phase.gap => const SizedBox.expand(),
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final ModuleIdentity identity;
  final ContentItem target;
  final int progress;
  final int total;
  final bool started;

  const _Header({
    required this.identity,
    required this.target,
    required this.progress,
    required this.total,
    required this.started,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusL,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Text(identity.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('FOCUS TAP · TARGET: ${target.label.toUpperCase()}',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          if (started)
            Text('$progress / $total',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: identity.accent)),
        ],
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  final ModuleIdentity identity;
  final ContentItem target;
  final VoidCallback onStart;

  const _ReadyView({
    required this.identity,
    required this.target,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: AppTheme.radiusXl,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: identity.gradient),
                shape: BoxShape.circle,
              ),
              child: Center(child: ItemVisual(item: target, size: 52)),
            ),
            const SizedBox(height: 16),
            Text('Tap only the ${target.label}!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Pictures will flash one at a time. Tap fast when you see '
              'the ${target.label} — and don\'t tap anything else!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StimulusView extends StatelessWidget {
  final _Stimulus stimulus;
  final int displayMs;
  final bool? tapCorrect;
  final Color accent;
  final void Function(TapDownDetails) onTapDown;

  const _StimulusView({
    super.key,
    required this.stimulus,
    required this.displayMs,
    required this.tapCorrect,
    required this.accent,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color border = switch (tapCorrect) {
      true => AppTheme.success,
      false => scheme.error,
      null => AppTheme.border,
    };

    // The whole stage is the tap surface — reaction measurement should never
    // be confounded by aiming precision on a small tile.
    return GestureDetector(
      key: const ValueKey('stimulus-surface'),
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: AppTheme.radiusXl,
                border: Border.all(color: border, width: 4),
              ),
              child: Center(child: ItemVisual(item: stimulus.item, size: 96)),
            ),
            const SizedBox(height: 24),
            CountdownBar(
                duration: Duration(milliseconds: displayMs), color: accent),
          ],
        ),
      ),
    );
  }
}
