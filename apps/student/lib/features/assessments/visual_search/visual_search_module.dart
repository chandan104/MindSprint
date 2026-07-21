import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../core/widgets/countdown_bar.dart';
import '../domain/assessment_models.dart';
import '../engine/assessment_module.dart';
import '../widgets/item_visual.dart';

class VisualSearchModule implements AssessmentModule {
  @override
  String get moduleKey => 'visual_search';

  @override
  String get displayName => 'Visual Search';

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      VisualSearchRunner(runContext: context);
}

/// Config knobs (contracts/levels/v1/visual_search.config.json).
class _Config {
  final int trialCount;
  final int gridSize;
  final double targetPresentRatio;
  final int timeLimitMsPerTrial;

  _Config(Map<String, Object?> raw)
      : trialCount = raw['trial_count'] as int,
        gridSize = raw['grid_size'] as int,
        targetPresentRatio = (raw['target_present_ratio'] as num).toDouble(),
        timeLimitMsPerTrial = raw['time_limit_ms_per_trial'] as int;
}

const String _notPresentId = 'not_present';
const String _notPresentLabel = 'Not here!';

class _Trial {
  final ContentItem target; // the item to search for (shown as the prompt)
  final bool present; // whether target is actually in the grid
  final List<ContentItem> grid;

  const _Trial({required this.target, required this.present, required this.grid});
}

enum _Phase { ready, trial, betweenTrials }

/// Grid search (Umbra world): find the named target among distractors, or
/// correctly declare it absent. Reuses the question_displayed /
/// tap_registered / answer_submitted contract (options = grid items + a
/// "not_present" sentinel; expected_answer = target label or "not_present")
/// so canonical metrics, replay, and upload work with zero engine changes.
class VisualSearchRunner extends StatefulWidget {
  final AssessmentRunContext runContext;
  final Random? random;

  const VisualSearchRunner({super.key, required this.runContext, this.random});

  @override
  State<VisualSearchRunner> createState() => _VisualSearchRunnerState();
}

class _VisualSearchRunnerState extends State<VisualSearchRunner> {
  late final _Config _config;
  late final Random _rng;

  _Phase _phase = _Phase.ready;
  var _trialNumber = 0;
  _Trial? _trial;
  String? _selectedId;
  bool? _lastCorrect;
  Timer? _trialTimer;
  Timer? _advanceTimer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('visual_search');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _rng = widget.random ?? Random();
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  _Trial _buildTrial() {
    final pool = [..._run.items]..shuffle(_rng);
    final present = _rng.nextDouble() < _config.targetPresentRatio;
    final target = pool.first;
    final gridPool = pool.skip(1).take(_config.gridSize - 1).toList();
    final grid = present
        ? ([...gridPool, target]..shuffle(_rng))
        : (gridPool.length >= _config.gridSize - 1
            ? gridPool
            : pool.skip(1).take(_config.gridSize - 1).toList());
    return _Trial(target: target, present: present, grid: grid);
  }

  void _nextTrial() {
    if (_trialNumber >= _config.trialCount) {
      _run.onFinished(AssessmentOutcome.completed);
      return;
    }
    final trial = _buildTrial();
    setState(() {
      _trialNumber++;
      _trial = trial;
      _selectedId = null;
      _lastCorrect = null;
      _phase = _Phase.trial;
    });

    _run.recorder.record('question_displayed', {
      'question_text': 'Find the ${trial.target.label}!',
      'expected_answer': trial.present ? trial.target.label : _notPresentId,
      'options': [
        for (final item in trial.grid) {'item_id': item.id, 'label': item.label},
        {'item_id': _notPresentId, 'label': _notPresentLabel},
      ],
    });

    _trialTimer?.cancel();
    _trialTimer =
        Timer(Duration(milliseconds: _config.timeLimitMsPerTrial), () {
      if (!mounted || _phase != _Phase.trial || _selectedId != null) return;
      _run.recorder.record('answer_submitted', {
        'answer': 'timeout',
        'is_correct': false,
      });
      _showFeedbackThenAdvance(correct: false);
    });
  }

  void _onTap(String itemId, String label, TapDownDetails details) {
    if (_phase != _Phase.trial || _selectedId != null) return;
    final trial = _trial!;
    final isCorrect = trial.present
        ? itemId == trial.target.id
        : itemId == _notPresentId;

    _trialTimer?.cancel();
    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': itemId,
      'label': label,
      'is_correct': isCorrect,
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _selectedId = itemId);
    _showFeedbackThenAdvance(correct: isCorrect);
  }

  void _showFeedbackThenAdvance({required bool correct}) {
    setState(() {
      _lastCorrect = correct;
      _phase = _Phase.betweenTrials;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _nextTrial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressBadge(
            identity: _identity, current: _trialNumber, total: _config.trialCount),
        Expanded(
          child: switch (_phase) {
            _Phase.ready => _ReadyView(identity: _identity, onStart: _nextTrial),
            _Phase.trial || _Phase.betweenTrials => _TrialView(
                key: ValueKey('trial$_trialNumber'),
                trial: _trial!,
                identity: _identity,
                timeLimitMs: _config.timeLimitMsPerTrial,
                selectedId: _selectedId,
                lastCorrect: _lastCorrect,
                acceptingInput: _phase == _Phase.trial,
                onTap: _onTap,
              ),
          },
        ),
      ],
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final ModuleIdentity identity;
  final int current;
  final int total;

  const _ProgressBadge(
      {required this.identity, required this.current, required this.total});

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
            child: Text('VISUAL SEARCH', style: Theme.of(context).textTheme.labelSmall),
          ),
          Text(
            current == 0 ? '$total trials' : '$current / $total',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: identity.accent),
          ),
        ],
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  final ModuleIdentity identity;
  final VoidCallback onStart;

  const _ReadyView({required this.identity, required this.onStart});

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: identity.gradient),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(identity.emoji, style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            Text('Sharp eyes!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Find the named picture in the grid as fast as you can. '
              "If it isn't there, tap \"Not here!\"",
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

class _TrialView extends StatelessWidget {
  final _Trial trial;
  final ModuleIdentity identity;
  final int timeLimitMs;
  final String? selectedId;
  final bool? lastCorrect;
  final bool acceptingInput;
  final void Function(String, String, TapDownDetails) onTap;

  const _TrialView({
    super.key,
    required this.trial,
    required this.identity,
    required this.timeLimitMs,
    required this.selectedId,
    required this.lastCorrect,
    required this.acceptingInput,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (acceptingInput)
            CountdownBar(
                duration: Duration(milliseconds: timeLimitMs), color: identity.accent)
          else
            Icon(
              lastCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 28,
              color: lastCorrect == true ? AppTheme.success : scheme.error,
            ),
          const SizedBox(height: 12),
          Text('Find the ${trial.target.label}!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final item in trial.grid)
                  _GridTile(
                    key: ValueKey('cell-${item.id}'),
                    item: item,
                    state: !acceptingInput && item.id == selectedId
                        ? (lastCorrect == true ? _TileState.correct : _TileState.wrong)
                        : !acceptingInput &&
                                trial.present &&
                                item.id == trial.target.id
                            ? _TileState.reveal
                            : _TileState.idle,
                    onTapDown: acceptingInput
                        ? (details) => onTap(item.id, item.label, details)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _NotHereButton(
            selected: selectedId == _notPresentId,
            state: !acceptingInput && selectedId == _notPresentId
                ? (lastCorrect == true ? _TileState.correct : _TileState.wrong)
                : !acceptingInput && !trial.present
                    ? _TileState.reveal
                    : _TileState.idle,
            onTapDown: acceptingInput
                ? (details) => onTap(_notPresentId, _notPresentLabel, details)
                : null,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

enum _TileState { idle, correct, wrong, reveal }

class _GridTile extends StatelessWidget {
  final ContentItem item;
  final _TileState state;
  final void Function(TapDownDetails)? onTapDown;

  const _GridTile({super.key, required this.item, required this.state, this.onTapDown});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color borderColor) = switch (state) {
      _TileState.correct => (AppTheme.success.withValues(alpha: 0.2), AppTheme.success),
      _TileState.wrong => (scheme.error.withValues(alpha: 0.18), scheme.error),
      _TileState.reveal => (
          AppTheme.success.withValues(alpha: 0.1),
          AppTheme.success.withValues(alpha: 0.5)
        ),
      _TileState.idle => (AppTheme.surface, AppTheme.border),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(
            minWidth: AppTheme.minTouchTarget, minHeight: AppTheme.minTouchTarget),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppTheme.radiusL,
          border: Border.all(color: borderColor, width: state == _TileState.idle ? 1 : 2.5),
        ),
        child: Center(child: ItemVisual(item: item, size: 40)),
      ),
    );
  }
}

class _NotHereButton extends StatelessWidget {
  final bool selected;
  final _TileState state;
  final void Function(TapDownDetails)? onTapDown;

  const _NotHereButton(
      {required this.selected, required this.state, this.onTapDown});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color borderColor) = switch (state) {
      _TileState.correct => (AppTheme.success.withValues(alpha: 0.2), AppTheme.success),
      _TileState.wrong => (scheme.error.withValues(alpha: 0.18), scheme.error),
      _TileState.reveal => (
          AppTheme.success.withValues(alpha: 0.1),
          AppTheme.success.withValues(alpha: 0.5)
        ),
      _TileState.idle => (AppTheme.surface, AppTheme.border),
    };

    return GestureDetector(
      key: const ValueKey('cell-not_present'),
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: AppTheme.minTouchTarget),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppTheme.radiusL,
          border: Border.all(color: borderColor, width: state == _TileState.idle ? 1 : 2.5),
        ),
        child: Center(
          child: Text(_notPresentLabel,
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}
