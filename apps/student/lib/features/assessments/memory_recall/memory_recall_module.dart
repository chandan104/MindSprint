import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
/// contracts/levels/v1/memory_recall.config.json).
class _Config {
  final int sequenceLength;
  final int displayTimeMs;
  final int interItemGapMs;
  final int choiceGridSize;

  _Config(Map<String, Object?> raw)
      : sequenceLength = raw['sequence_length'] as int,
        displayTimeMs = raw['display_time_ms'] as int,
        interItemGapMs = raw['inter_item_gap_ms'] as int,
        choiceGridSize = raw['choice_grid_size'] as int;
}

enum _Phase { ready, showing, gap, recall }

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
  late final List<ContentItem> _sequence;
  late final List<ContentItem> _choices;

  _Phase _phase = _Phase.ready;
  int _showIndex = 0;
  int _expectedIndex = 0;
  final Set<String> _matchedItemIds = {};
  String? _wrongFlashItemId;
  Timer? _phaseTimer;
  Timer? _flashTimer;

  AssessmentRunContext get _run => widget.runContext;

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _rng = widget.random ?? Random();

    // Sequence: distinct random items. Choices: sequence + distractors,
    // shuffled once. Both are recorded into events so replay is
    // self-contained (ADR-009).
    final pool = [..._run.items]..shuffle(_rng);
    _sequence = pool.take(_config.sequenceLength).toList();
    final distractors = pool
        .skip(_config.sequenceLength)
        .take(max(0, _config.choiceGridSize - _config.sequenceLength))
        .toList();
    _choices = [..._sequence, ...distractors]..shuffle(_rng);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _begin() {
    _run.recorder.record('sequence_display_started', {
      'sequence': [
        for (final item in _sequence) {'item_id': item.id, 'label': item.label},
      ],
    });
    setState(() {
      _phase = _Phase.showing;
      _showIndex = 0;
    });
    _showCurrentItem();
  }

  void _showCurrentItem() {
    final item = _sequence[_showIndex];
    _run.recorder.record('item_displayed', {
      'item_id': item.id,
      'label': item.label,
      'position_index': _showIndex,
    });
    _phaseTimer = Timer(Duration(milliseconds: _config.displayTimeMs), () {
      if (!mounted) return;
      if (_showIndex + 1 >= _sequence.length) {
        _run.recorder.record('sequence_hidden');
        setState(() => _phase = _Phase.recall);
      } else {
        setState(() => _phase = _Phase.gap);
        _phaseTimer = Timer(Duration(milliseconds: _config.interItemGapMs), () {
          if (!mounted) return;
          setState(() {
            _showIndex++;
            _phase = _Phase.showing;
          });
          _showCurrentItem();
        });
      }
    });
  }

  void _onChoiceTap(ContentItem item, TapDownDetails details) {
    if (_phase != _Phase.recall) return;
    if (_matchedItemIds.contains(item.id)) return; // already matched

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
      setState(() {
        _matchedItemIds.add(item.id);
        _expectedIndex++;
        _wrongFlashItemId = null;
      });
      if (_expectedIndex >= _sequence.length) {
        _run.onFinished(AssessmentOutcome.completed);
      }
    } else {
      // Gentle feedback; the child retries. Wrong taps are still measured —
      // advance-on-correct keeps children from being stuck with a wrong
      // internal state while every error remains in the event log.
      setState(() => _wrongFlashItemId = item.id);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrongFlashItemId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.ready => _ReadyView(onStart: _begin),
      _Phase.showing => _ShowingView(item: _sequence[_showIndex]),
      _Phase.gap => const _GapView(),
      _Phase.recall => _RecallView(
          choices: _choices,
          matched: _matchedItemIds,
          wrongFlashItemId: _wrongFlashItemId,
          progress: _expectedIndex,
          total: _sequence.length,
          onTapDown: _onChoiceTap,
        ),
    };
  }
}

class _ReadyView extends StatelessWidget {
  final VoidCallback onStart;
  const _ReadyView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Watch carefully!',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Remember the order the pictures appear in.',
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _ShowingView extends StatelessWidget {
  final ContentItem item;
  const _ShowingView({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemVisual(item: item, size: 140),
          const SizedBox(height: 16),
          Text(item.label, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _GapView extends StatelessWidget {
  const _GapView();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _RecallView extends StatelessWidget {
  final List<ContentItem> choices;
  final Set<String> matched;
  final String? wrongFlashItemId;
  final int progress;
  final int total;
  final void Function(ContentItem, TapDownDetails) onTapDown;

  const _RecallView({
    required this.choices,
    required this.matched,
    required this.wrongFlashItemId,
    required this.progress,
    required this.total,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text('Tap them in the same order!',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$progress of $total',
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.all(16),
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
    final Color background = matched
        ? scheme.primaryContainer
        : wrongFlash
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest;

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
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: matched ? Border.all(color: scheme.primary, width: 3) : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemVisual(item: item, size: 56),
              const SizedBox(height: 6),
              Text(item.label,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis),
              if (matched) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
