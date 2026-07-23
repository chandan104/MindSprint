import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../core/widgets/countdown_bar.dart';
import '../domain/assessment_models.dart';
import '../engine/assessment_module.dart';
import 'question_generator.dart';

class MathSpeedModule implements AssessmentModule {
  @override
  String get moduleKey => 'math_speed';

  @override
  String get displayName => 'Mathematics Speed';

  @override
  bool get requiresContentItems => false; // generates arithmetic questions

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      MathSpeedRunner(runContext: context);
}

/// Config knobs (contracts/levels/v1/math_speed.config.json).
class _Config {
  final List<String> operations;
  final int questionCount;
  final int operandMin;
  final int operandMax;
  final int timeLimitMsPerQuestion;

  _Config(Map<String, Object?> raw)
      : operations = List<String>.from(raw['operations'] as List),
        questionCount = raw['question_count'] as int,
        operandMin = raw['operand_min'] as int,
        operandMax = raw['operand_max'] as int,
        timeLimitMsPerQuestion = raw['time_limit_ms_per_question'] as int;
}

enum _Phase { ready, question, betweenQuestions }

/// Math Speed Blitz (prototype's Ignis Prime world): one question at a time,
/// four big answer tiles, a per-question countdown. Every question emits
/// question_displayed (self-contained payload with options); every answer is
/// a tap_registered with correctness; a timeout emits answer_submitted with
/// is_correct=false so misses are measured, not lost.
class MathSpeedRunner extends StatefulWidget {
  final AssessmentRunContext runContext;
  final Random? random;

  const MathSpeedRunner({super.key, required this.runContext, this.random});

  @override
  State<MathSpeedRunner> createState() => _MathSpeedRunnerState();
}

class _MathSpeedRunnerState extends State<MathSpeedRunner> {
  late final _Config _config;
  late final MathQuestionGenerator _generator;

  _Phase _phase = _Phase.ready;
  var _questionNumber = 0; // 1-based once running
  MathQuestion? _question;
  int? _selectedOption;
  bool? _lastCorrect;
  Timer? _questionTimer;
  Timer? _advanceTimer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('math_speed');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _generator = MathQuestionGenerator(
      operations: _config.operations,
      operandMin: _config.operandMin,
      operandMax: _config.operandMax,
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
      'question_text': question.text,
      'expected_answer': '${question.answer}',
      'options': [
        for (final option in question.options)
          {'item_id': '$option', 'label': '$option'},
      ],
    });

    _questionTimer?.cancel();
    _questionTimer =
        Timer(Duration(milliseconds: _config.timeLimitMsPerQuestion), () {
      if (!mounted || _phase != _Phase.question || _selectedOption != null) {
        return;
      }
      // Timed out: a measured miss, not a lost data point.
      _run.recorder.record('answer_submitted', {
        'answer': 'timeout',
        'is_correct': false,
      });
      _showFeedbackThenAdvance(correct: false, timedOut: true);
    });
  }

  void _onOptionTap(int option, TapDownDetails details) {
    if (_phase != _Phase.question || _selectedOption != null) return;
    final question = _question!;
    final isCorrect = option == question.answer;

    _questionTimer?.cancel();
    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': '$option',
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
    _showFeedbackThenAdvance(correct: isCorrect, timedOut: false);
  }

  void _showFeedbackThenAdvance({required bool correct, required bool timedOut}) {
    setState(() {
      _lastCorrect = correct;
      _phase = _Phase.betweenQuestions;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 650), () {
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
            _Phase.ready => _ReadyView(identity: _identity, onStart: _nextQuestion),
            _Phase.question ||
            _Phase.betweenQuestions =>
              _QuestionView(
                key: ValueKey('q$_questionNumber'),
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

  const _ProgressBadge({
    required this.identity,
    required this.current,
    required this.total,
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
            child: Text('MATHEMATICS SPEED',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          Text(
            current == 0 ? '$total questions' : '$current / $total',
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
            Text('Quick maths!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Solve each question by tapping the right answer. '
              'Be fast — but be right!',
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
  final MathQuestion question;
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  identity.gradient.first.withValues(alpha: 0.18),
                  identity.gradient.last.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: AppTheme.radiusXl,
              border:
                  Border.all(color: identity.accent.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                '${question.text} = ?',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.9,
              children: [
                for (final option in question.options)
                  _AnswerTile(
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

enum _TileState { idle, correct, wrong, reveal }

class _AnswerTile extends StatelessWidget {
  final int value;
  final _TileState state;
  final void Function(TapDownDetails)? onTapDown;

  const _AnswerTile({required this.value, required this.state, this.onTapDown});

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
      key: ValueKey('answer-$value'),
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
          child: Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
