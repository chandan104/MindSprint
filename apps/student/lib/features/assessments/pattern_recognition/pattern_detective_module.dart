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
import 'pattern_generator.dart';

class PatternDetectiveModule implements AssessmentModule {
  @override
  String get moduleKey => 'pattern_recognition';

  @override
  String get displayName => 'Pattern Detective';

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      PatternDetectiveRunner(runContext: context);
}

/// Config knobs (contracts/levels/v1/pattern_recognition.config.json).
class _Config {
  final List<String> patternKinds;
  final int questionCount;
  final int sequenceLength;
  final int optionCount;
  final int timeLimitMsPerQuestion;

  _Config(Map<String, Object?> raw)
      : patternKinds = List<String>.from(raw['pattern_kinds'] as List),
        questionCount = raw['question_count'] as int,
        sequenceLength = raw['sequence_length'] as int,
        optionCount = raw['option_count'] as int,
        timeLimitMsPerQuestion = raw['time_limit_ms_per_question'] as int;
}

enum _Phase { ready, question, betweenQuestions }

/// Pattern completion (Prisma world — Crystal Canyons): find the rule,
/// complete the sequence. Emits the same event contract as Mathematics
/// Speed: question_displayed with self-contained sequence + options payload,
/// one tap_registered per answer, answer_submitted 'timeout' for misses —
/// so metrics, replay, and upload all work unchanged.
class PatternDetectiveRunner extends StatefulWidget {
  final AssessmentRunContext runContext;
  final Random? random;

  const PatternDetectiveRunner(
      {super.key, required this.runContext, this.random});

  @override
  State<PatternDetectiveRunner> createState() =>
      _PatternDetectiveRunnerState();
}

class _PatternDetectiveRunnerState extends State<PatternDetectiveRunner> {
  late final _Config _config;
  late final PatternGenerator _generator;

  _Phase _phase = _Phase.ready;
  var _questionNumber = 0;
  PatternQuestion? _question;
  String? _selectedItemId;
  bool? _lastCorrect;
  Timer? _questionTimer;
  Timer? _advanceTimer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('pattern_recognition');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _generator = PatternGenerator(
      kinds: _config.patternKinds,
      sequenceLength: _config.sequenceLength,
      optionCount: _config.optionCount,
      pool: _run.items,
      random: widget.random,
    );
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    if (_questionNumber >= _config.questionCount) {
      _run.onFinished(AssessmentOutcome.completed);
      return;
    }
    final question = _generator.next();
    setState(() {
      _questionNumber++;
      _question = question;
      _selectedItemId = null;
      _lastCorrect = null;
      _phase = _Phase.question;
    });

    _run.recorder.record('question_displayed', {
      'question_text': 'What comes next? (${question.kind} pattern)',
      'expected_answer': question.answer.label,
      'sequence': [
        for (final item in question.shown)
          {'item_id': item.id, 'label': item.label},
      ],
      'options': [
        for (final item in question.options)
          {'item_id': item.id, 'label': item.label},
      ],
    });

    _questionTimer?.cancel();
    _questionTimer =
        Timer(Duration(milliseconds: _config.timeLimitMsPerQuestion), () {
      if (!mounted || _phase != _Phase.question || _selectedItemId != null) {
        return;
      }
      _run.recorder.record('answer_submitted', {
        'answer': 'timeout',
        'is_correct': false,
      });
      _showFeedbackThenAdvance(correct: false);
    });
  }

  void _onOptionTap(ContentItem option, TapDownDetails details) {
    if (_phase != _Phase.question || _selectedItemId != null) return;
    final question = _question!;
    final isCorrect = option.id == question.answer.id;

    _questionTimer?.cancel();
    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': option.id,
      'label': option.label,
      'is_correct': isCorrect,
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _selectedItemId = option.id);
    _showFeedbackThenAdvance(correct: isCorrect);
  }

  void _showFeedbackThenAdvance({required bool correct}) {
    setState(() {
      _lastCorrect = correct;
      _phase = _Phase.betweenQuestions;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _nextQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressBadge(
          identity: _identity,
          current: _questionNumber,
          total: _config.questionCount,
        ),
        Expanded(
          child: switch (_phase) {
            _Phase.ready =>
              _ReadyView(identity: _identity, onStart: _nextQuestion),
            _Phase.question || _Phase.betweenQuestions => _QuestionView(
                key: ValueKey('pq$_questionNumber'),
                question: _question!,
                identity: _identity,
                timeLimitMs: _config.timeLimitMsPerQuestion,
                selectedItemId: _selectedItemId,
                lastCorrect: _lastCorrect,
                acceptingInput: _phase == _Phase.question,
                onTapDown: _onOptionTap,
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
            child: Text('PATTERN DETECTIVE',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          Text(
            current == 0 ? '$total puzzles' : '$current / $total',
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
                  child: Text(identity.emoji,
                      style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            Text('Crack the pattern!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Each puzzle follows a secret rule. Look at the row, find the '
              'rule, and tap what comes next!',
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

class _QuestionView extends StatelessWidget {
  final PatternQuestion question;
  final ModuleIdentity identity;
  final int timeLimitMs;
  final String? selectedItemId;
  final bool? lastCorrect;
  final bool acceptingInput;
  final void Function(ContentItem, TapDownDetails) onTapDown;

  const _QuestionView({
    super.key,
    required this.question,
    required this.identity,
    required this.timeLimitMs,
    required this.selectedItemId,
    required this.lastCorrect,
    required this.acceptingInput,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (acceptingInput)
            CountdownBar(
                duration: Duration(milliseconds: timeLimitMs),
                color: identity.accent)
          else
            Icon(
              lastCorrect == true
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 32,
              color: lastCorrect == true ? AppTheme.success : scheme.error,
            ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  identity.gradient.first.withValues(alpha: 0.15),
                  identity.gradient.last.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: AppTheme.radiusXl,
              border:
                  Border.all(color: identity.accent.withValues(alpha: 0.3)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final item in question.shown)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Center(child: ItemVisual(item: item, size: 34)),
                  ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: identity.accent, width: 2),
                  ),
                  child: Center(
                    child: Text('?',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: identity.accent)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.6,
              children: [
                for (final option in question.options)
                  _OptionTile(
                    option: option,
                    state: !acceptingInput && option.id == selectedItemId
                        ? (lastCorrect == true
                            ? _TileState.correct
                            : _TileState.wrong)
                        : !acceptingInput && option.id == question.answer.id
                            ? _TileState.reveal
                            : _TileState.idle,
                    onTapDown: acceptingInput
                        ? (details) => onTapDown(option, details)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TileState { idle, correct, wrong, reveal }

class _OptionTile extends StatelessWidget {
  final ContentItem option;
  final _TileState state;
  final void Function(TapDownDetails)? onTapDown;

  const _OptionTile(
      {required this.option, required this.state, this.onTapDown});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color borderColor) = switch (state) {
      _TileState.correct => (
          AppTheme.success.withValues(alpha: 0.2),
          AppTheme.success
        ),
      _TileState.wrong => (scheme.error.withValues(alpha: 0.18), scheme.error),
      _TileState.reveal => (
          AppTheme.success.withValues(alpha: 0.1),
          AppTheme.success.withValues(alpha: 0.5)
        ),
      _TileState.idle => (AppTheme.surface, AppTheme.border),
    };

    return GestureDetector(
      key: ValueKey('pattern-option-${option.id}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(
            minWidth: AppTheme.minTouchTarget,
            minHeight: AppTheme.minTouchTarget),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppTheme.radiusL,
          border: Border.all(
              color: borderColor, width: state == _TileState.idle ? 1 : 2.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemVisual(item: option, size: 44),
              const SizedBox(height: 4),
              Text(option.label,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
