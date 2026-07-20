import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../assessments/domain/assessment_models.dart';
import '../../session/domain/session_args.dart';
import '../domain/provisional_metrics.dart';

/// Instant result screen from PROVISIONAL metrics (server recomputes the
/// canonical values after upload). Language is deliberately educational and
/// encouraging — effort-focused, never diagnostic, no norms or percentiles.
class ResultScreen extends StatelessWidget {
  final ConfirmedStudent student;
  final AssessmentLevel level;
  final ProvisionalMetrics metrics;
  final bool wasInterrupted;

  const ResultScreen({
    super.key,
    required this.student,
    required this.level,
    required this.metrics,
    required this.wasInterrupted,
  });

  int get _stars {
    final accuracy = metrics.accuracy;
    if (accuracy == null) return 0;
    if (accuracy >= 0.9) return 3;
    if (accuracy >= 0.7) return 2;
    if (accuracy >= 0.5) return 1;
    return 0;
  }

  String get _headline => switch (_stars) {
        3 => 'Amazing work!',
        2 => 'Great job!',
        1 => 'Good effort!',
        _ => 'Nice try — practice makes progress!',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = metrics.accuracy;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CelebrationStars(earned: _stars),
                  const SizedBox(height: 12),
                  Text(_headline, style: theme.textTheme.headlineMedium),
                  Text(student.studentName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _StatChip(
                        icon: Icons.timer_outlined,
                        label: 'Time',
                        value:
                            '${(metrics.totalTimeMs / 1000).toStringAsFixed(1)}s',
                      ),
                      if (accuracy != null)
                        _StatChip(
                          icon: Icons.check_circle_outline,
                          label: 'Correct',
                          value:
                              '${metrics.correctCount} of ${metrics.totalAnswers}',
                        ),
                      if (metrics.meanDecisionMs != null)
                        _StatChip(
                          icon: Icons.bolt_outlined,
                          label: 'Thinking speed',
                          value:
                              '${(metrics.meanDecisionMs! / 1000).toStringAsFixed(1)}s',
                        ),
                    ],
                  ),
                  if (wasInterrupted) ...[
                    const SizedBox(height: 16),
                    Text(
                      'This session was interrupted, so its timing will not '
                      'be used for comparisons.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go(AppRoutes.studentsFor(student.classId)),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Back to students'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stars pop in one by one with a spring curve and a light haptic tick —
/// the celebration a child waits for. Pure presentation; metrics decided
/// the count long before this widget existed.
class _CelebrationStars extends StatefulWidget {
  final int earned;
  const _CelebrationStars({required this.earned});

  @override
  State<_CelebrationStars> createState() => _CelebrationStarsState();
}

class _CelebrationStarsState extends State<_CelebrationStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  int _hapticsFired = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeTick);
    _controller.forward();
  }

  void _maybeTick() {
    final reached = (_controller.value * 3).floor().clamp(0, widget.earned);
    if (reached > _hapticsFired) {
      _hapticsFired = reached;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final start = i * 0.28;
              final t = Curves.elasticOut.transform(
                  ((_controller.value - start) / 0.4).clamp(0.0, 1.0));
              final earnedStar = i < widget.earned;
              return Transform.scale(
                scale: earnedStar ? t : 1,
                child: Icon(
                  earnedStar
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 64,
                  color: earnedStar
                      ? Colors.amber
                      : theme.colorScheme.outlineVariant,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
