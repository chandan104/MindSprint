import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/accessibility/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../core/widgets/countdown_bar.dart';
import '../domain/assessment_models.dart';
import '../engine/assessment_module.dart';
import '../widgets/item_visual.dart';

class MemoryRecallModule implements AssessmentModule {
  @override
  String get moduleKey => 'memory_recall';

  @override
  String get displayName => 'Memory Recall';

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      MemoryRecallRunner(runContext: context);
}

/// Config knobs (validated server-side against
/// contracts/levels/v1/memory_recall.config.json). trial_count is optional
/// and additive: older level versions without it play a single round.
class _Config {
  final int sequenceLength;
  final int displayTimeMs;
  final int interItemGapMs;
  final int choiceGridSize;
  final int trialCount;

  _Config(Map<String, Object?> raw)
      : sequenceLength = raw['sequence_length'] as int,
        displayTimeMs = raw['display_time_ms'] as int,
        interItemGapMs = raw['inter_item_gap_ms'] as int,
        choiceGridSize = raw['choice_grid_size'] as int,
        trialCount = raw['trial_count'] as int? ?? 1;
}

enum _Phase { ready, exposure, recall, roundDone }

/// Presentation adopted from the AI Studio prototype: items REVEAL one by
/// one into a visible row (each reveal is an item_displayed event with its
/// exact monotonic timestamp), the whole row stays visible until
/// sequence_hidden, then the child rebuilds the order into placeholder
/// slots from a distractor grid. Multi-round levels repeat with a fresh
/// sequence; every round's events share the one session log.
class MemoryRecallRunner extends StatefulWidget {
  final AssessmentRunContext runContext;

  /// Injectable RNG so tests get deterministic sequences.
  final Random? random;

  const MemoryRecallRunner({super.key, required this.runContext, this.random});

  @override
  State<MemoryRecallRunner> createState() => _MemoryRecallRunnerState();
}

class _MemoryRecallRunnerState extends State<MemoryRecallRunner> {
  late final _Config _config;
  late final Random _rng;

  var _round = 1;
  var _sequence = <ContentItem>[];
  var _choices = <ContentItem>[];
  var _revealedCount = 0;

  _Phase _phase = _Phase.ready;
  int _expectedIndex = 0;
  final Set<String> _matchedItemIds = {};
  String? _wrongFlashItemId;
  Timer? _phaseTimer;
  Timer? _flashTimer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('memory_recall');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _rng = widget.random ?? Random();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _beginRound() {
    final pool = [..._run.items]..shuffle(_rng);
    _sequence = pool.take(_config.sequenceLength).toList();
    final distractors = pool
        .skip(_config.sequenceLength)
        .take(max(0, _config.choiceGridSize - _config.sequenceLength))
        .toList();
    _choices = [..._sequence, ...distractors]..shuffle(_rng);
    _expectedIndex = 0;
    _matchedItemIds.clear();
    _wrongFlashItemId = null;
    _revealedCount = 0;

    _run.recorder.record('sequence_display_started', {
      'sequence': [
        for (final item in _sequence) {'item_id': item.id, 'label': item.label},
      ],
    });
    setState(() => _phase = _Phase.exposure);
    _revealNext();
  }

  void _revealNext() {
    final index = _revealedCount;
    final item = _sequence[index];
    _run.recorder.record('item_displayed', {
      'item_id': item.id,
      'label': item.label,
      'position_index': index,
    });
    setState(() => _revealedCount = index + 1);

    _phaseTimer = Timer(
      Duration(
          milliseconds: _config.displayTimeMs +
              (index + 1 < _sequence.length ? _config.interItemGapMs : 0)),
      () {
        if (!mounted) return;
        if (_revealedCount < _sequence.length) {
          _revealNext();
        } else {
          _run.recorder.record('sequence_hidden');
          setState(() => _phase = _Phase.recall);
        }
      },
    );
  }

  void _onChoiceTap(ContentItem item, TapDownDetails details) {
    if (_phase != _Phase.recall) return;
    if (_matchedItemIds.contains(item.id)) return;

    final expected = _sequence[_expectedIndex];
    final isCorrect = item.id == expected.id;

    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': item.id,
      'label': item.label,
      'is_correct': isCorrect,
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      setState(() {
        _matchedItemIds.add(item.id);
        _expectedIndex++;
        _wrongFlashItemId = null;
      });
      if (_expectedIndex >= _sequence.length) {
        _onRoundComplete();
      }
    } else {
      // Gentle feedback; the child retries. Every error stays in the log.
      HapticFeedback.heavyImpact();
      setState(() => _wrongFlashItemId = item.id);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrongFlashItemId = null);
      });
    }
  }

  void _onRoundComplete() {
    if (_round >= _config.trialCount) {
      _run.onFinished(AssessmentOutcome.completed);
      return;
    }
    setState(() => _phase = _Phase.roundDone);
    _phaseTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _round++;
        _phase = _Phase.ready;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoundBadge(
            identity: _identity, round: _round, total: _config.trialCount),
        Expanded(
          child: switch (_phase) {
            _Phase.ready => _ReadyView(
                identity: _identity,
                round: _round,
                totalRounds: _config.trialCount,
                onStart: _beginRound,
              ),
            _Phase.exposure => _ExposureView(
                sequence: _sequence,
                revealedCount: _revealedCount,
                totalMs: _sequence.length * _config.displayTimeMs +
                    (_sequence.length - 1) * _config.interItemGapMs,
                accent: _identity.accent,
              ),
            _Phase.recall => _RecallView(
                sequence: _sequence,
                choices: _choices,
                matched: _matchedItemIds,
                expectedIndex: _expectedIndex,
                wrongFlashItemId: _wrongFlashItemId,
                onTapDown: _onChoiceTap,
              ),
            _Phase.roundDone => const _RoundDoneView(),
          },
        ),
      ],
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final ModuleIdentity identity;
  final int round;
  final int total;

  const _RoundBadge(
      {required this.identity, required this.round, required this.total});

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
            child: Text(
              'MEMORY RECALL',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (total > 1)
            Text(
              'Round $round / $total',
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
  final int round;
  final int totalRounds;
  final VoidCallback onStart;

  const _ReadyView({
    required this.identity,
    required this.round,
    required this.totalRounds,
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: identity.gradient),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(identity.emoji,
                      style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            Text(
              round == 1 ? 'Watch carefully!' : 'Round $round — ready?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pictures will appear one by one. Remember their order, then '
              'tap them back in the same order!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(round == 1 ? 'Start' : 'Go!'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExposureView extends StatelessWidget {
  final List<ContentItem> sequence;
  final int revealedCount;
  final int totalMs;
  final Color accent;

  const _ExposureView({
    required this.sequence,
    required this.revealedCount,
    required this.totalMs,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = reducedMotion(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('WATCH AND MEMORIZE',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: accent)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: AppTheme.radiusXl,
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < sequence.length; i++)
                  AnimatedScale(
                    scale: i < revealedCount ? 1 : 0,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: AppTheme.radiusL,
                        border: Border.all(
                            color: accent.withValues(alpha: 0.6), width: 2),
                      ),
                      child: Center(
                          child: ItemVisual(item: sequence[i], size: 44)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          CountdownBar(
              duration: Duration(milliseconds: totalMs), color: accent),
        ],
      ),
    );
  }
}

class _RecallView extends StatelessWidget {
  final List<ContentItem> sequence;
  final List<ContentItem> choices;
  final Set<String> matched;
  final int expectedIndex;
  final String? wrongFlashItemId;
  final void Function(ContentItem, TapDownDetails) onTapDown;

  const _RecallView({
    required this.sequence,
    required this.choices,
    required this.matched,
    required this.expectedIndex,
    required this.wrongFlashItemId,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        Text('TAP THEM IN THE SAME ORDER',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        // Placeholder slots: filled as the child rebuilds the sequence.
        Wrap(
          spacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < sequence.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: i < expectedIndex
                      ? AppTheme.surfaceHigh
                      : AppTheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        i < expectedIndex ? scheme.primary : AppTheme.border,
                    width: i < expectedIndex ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: i < expectedIndex
                      ? ItemVisual(item: sequence[i], size: 30)
                      : Text('?',
                          style: TextStyle(
                              fontSize: 22, color: AppTheme.textDim)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            crossAxisCount: choices.length <= 6 ? 2 : 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final item in choices)
                _ChoiceTile(
                  item: item,
                  matched: matched.contains(item.id),
                  wrongFlash: wrongFlashItemId == item.id,
                  scheme: scheme,
                  onTapDown: (details) => onTapDown(item, details),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundDoneView extends StatelessWidget {
  const _RoundDoneView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 72, color: AppTheme.success),
          const SizedBox(height: 12),
          Text('Round complete!',
              style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final ContentItem item;
  final bool matched;
  final bool wrongFlash;
  final ColorScheme scheme;
  final void Function(TapDownDetails) onTapDown;

  const _ChoiceTile({
    required this.item,
    required this.matched,
    required this.wrongFlash,
    required this.scheme,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = matched
        ? scheme.primary
        : wrongFlash
            ? scheme.error
            : AppTheme.border;

    // GestureDetector.onTapDown (not onTap): the timestamp of finger-down is
    // the measurement instant; onTap fires on finger-up.
    return GestureDetector(
      key: ValueKey('choice-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: matched ? null : onTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(
            minWidth: AppTheme.minTouchTarget,
            minHeight: AppTheme.minTouchTarget),
        decoration: BoxDecoration(
          color: matched
              ? AppTheme.surfaceHigh
              : wrongFlash
                  ? scheme.error.withValues(alpha: 0.15)
                  : AppTheme.surface,
          borderRadius: AppTheme.radiusL,
          border: Border.all(color: borderColor, width: matched ? 3 : 1),
        ),
        child: Opacity(
          opacity: matched ? 0.45 : 1,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ItemVisual(item: item, size: 52),
                const SizedBox(height: 6),
                Text(item.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis),
                // Icon accompanies color on every state (colorblind-safe):
                // never rely on red/green alone.
                if (matched)
                  Icon(Icons.check_circle, color: scheme.primary, size: 20)
                else if (wrongFlash)
                  Icon(Icons.cancel, color: scheme.error, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
