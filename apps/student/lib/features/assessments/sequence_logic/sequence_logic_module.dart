import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../core/widgets/countdown_bar.dart';
import '../domain/assessment_models.dart';
import '../engine/assessment_module.dart';
import 'series_generator.dart';

class SequenceLogicModule implements AssessmentModule {
  @override
  String get moduleKey => 'sequence_logic';

  @override
  String get displayName => 'Sequence Logic';

  @override
  bool get requiresContentItems => false; // generates number series

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      SequenceLogicRunner(runContext: context);
}

/// Config knobs (contracts/levels/v1/sequence_logic.config.json).
class _Config {
  final List<String> logicKinds;
  final int questionCount;
  final int sequenceLength;
  final int timeLimitMsPerQuestion;

  _Config(Map<String, Object?> raw)
      : logicKinds = List<String>.from(raw['logic_kinds'] as List),
        questionCount = raw['question_count'] as int,
        sequenceLength = raw['sequence_length'] as int,
        timeLimitMsPerQuestion = raw['time_limit_ms_per_question'] as int;
}

enum _Phase { ready, question, betweenQuestions }

/// Next-in-series reasoning (Meridian world — Clockwork City): infer the rule
/// of an ordered number run and pick what comes next. Content is generated
/// numbers (not category items). Reuses the question_displayed /
/// tap_registered / answer_submitted contract, so metrics, replay, and upload
/// need zero changes.
class SequenceLogicRunner extends StatefulWidget {
  final AssessmentRunContext runContext;
  final Random? random;

  const SequenceLogicRunner({super.key, required this.runContext, this.random});

  @override
  State<SequenceLogicRunner> createState() => _SequenceLogicRunnerState();
}

class _SequenceLogicRunnerState extends State<SequenceLogicRunner> {
  late final _Config _config;
  late final SeriesGenerator _generator;

  _Phase _phase = _Phase.ready;
  var _questionNumber = 0;
  SeriesQuestion? _question;
  int? _selectedOption;
  bool? _lastCorrect;
  Timer? _questionTimer;
  Timer? _advanceTimer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('sequence_logic');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _generator = SeriesGenerator(
      kinds: _config.logicKinds,
      sequenceLength: _config.sequenceLength,
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
      _selectedOption = null;
      _lastCorrect = null;
      _phase = _Phase.question;
    });

    _run.recorder.record('question_displayed', {
      'question_text': 'What comes next? (${question.kind})',
      'expected_answer': '${question.answer}',
      'sequence': [
        for (final n in question.shown) {'item_id': 'n$n', 'label': '$n'},
      ],
      'options': [
        for (final n in question.options) {'item_id': 'n$n', 'label': '$n'},
      ],
    });

    _questionTimer?.cancel();
    _questionTimer =
        Timer(Duration(milliseconds: _config.timeLimitMsPerQuestion), () {
      if (!mounted || _phase != _Phase.question || _selectedOption != null) {
        return;
      }
      _run.recorder.record('answer_submitted', {
        'answer': 'timeout',
        'is_correct': false,
      });
      _showFeedbackThenAdvance(correct: false);
    });
  }

  void _onOptionTap(int option, TapDownDetails details) {
    if (_phase != _Phase.question || _selectedOption != null) return;
    final question = _question!;
    final isCorrect = option == question.answer;

    _questionTimer?.cancel();
    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': 'n$option',
      'label': '$option',
      'is_correct': isCorrect,
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _selectedOption = option);
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
                key: ValueKey('sq$_questionNumber'),
                question: _question!,
                identity: _identity,
                timeLimitMs: _config.timeLimitMsPerQuestion,
                selectedOption: _selectedOption,
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
            child: Text('SEQUENCE LOGIC',
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
            Text('Find the pattern in the numbers!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Look at the numbers in a row. Work out the rule, then tap the '
              'number that comes next!',
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
  final SeriesQuestion question;
  final ModuleIdentity identity;
  final int timeLimitMs;
  final int? selectedOption;
  final bool? lastCorrect;
  final bool acceptingInput;
  final void Function(int, TapDownDetails) onTapDown;

  const _QuestionView({
    super.key,
    required this.question,
    required this.identity,
    required this.timeLimitMs,
    required this.selectedOption,
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
                for (final n in question.shown)
                  _NumberChip(text: '$n', border: AppTheme.border),
                _NumberChip(text: '?', border: identity.accent, accent: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.4,
              children: [
                for (final option in question.options)
                  _OptionTile(
                    value: option,
                    state: !acceptingInput && option == selectedOption
                        ? (lastCorrect == true
                            ? _TileState.correct
                            : _TileState.wrong)
                        : !acceptingInput && option == question.answer
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

class _NumberChip extends StatelessWidget {
  final String text;
  final Color border;
  final bool accent;

  const _NumberChip(
      {required this.text, required this.border, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: accent ? 2 : 1),
      ),
      child: Center(
        child: Text(text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent ? border : null)),
      ),
    );
  }
}

enum _TileState { idle, correct, wrong, reveal }

class _OptionTile extends StatelessWidget {
  final int value;
  final _TileState state;
  final void Function(TapDownDetails)? onTapDown;

  const _OptionTile(
      {required this.value, required this.state, this.onTapDown});

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
      key: ValueKey('series-option-$value'),
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
          child: Text('$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
