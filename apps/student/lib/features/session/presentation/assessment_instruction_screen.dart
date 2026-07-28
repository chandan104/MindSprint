import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../assessments/domain/assessment_models.dart';

/// One consistent, premium "how to play" screen shown before EVERY assessment.
/// The session clock only starts when the child taps Start, so reading these
/// instructions never counts against their timing or scores.
class AssessmentInstructionScreen extends StatelessWidget {
  final AssessmentLevel level;
  final String moduleName;
  final VoidCallback onStart;

  const AssessmentInstructionScreen({
    super.key,
    required this.level,
    required this.moduleName,
    required this.onStart,
  });

  static const _howToPlay = <String, String>{
    'memory_recall':
        'Watch the items appear one by one. Remember their order — then tap '
            'them back in the same order.',
    'math_speed':
        'Solve each problem as fast as you can, then tap the correct answer.',
    'attention_focus':
        'Pictures flash by one at a time. Tap ONLY when you see the target — '
            'and hold still for everything else.',
    'pattern_recognition':
        'Each row follows a secret rule. Find it, then tap the picture that '
            'completes the pattern.',
    'visual_search':
        'Find the named picture as fast as you can. If it isn\'t there, tap '
            '“Not here!”.',
    'sequence_logic':
        'Work out the rule behind the numbers, then tap what comes next.',
    'color_selector':
        'Read each instruction carefully, then tap the right colour. Watch '
            'out — the words can try to trick you!',
  };

  String get _tier {
    final i = level.name.lastIndexOf('—');
    if (i != -1) {
      final t = level.name.substring(i + 1).trim();
      if (t.isNotEmpty) return t;
    }
    return level.difficulty.isEmpty
        ? ''
        : level.difficulty[0].toUpperCase() + level.difficulty.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final identity = moduleIdentity(level.moduleKey);
    final how = _howToPlay[level.moduleKey] ??
        'Follow the instructions on screen and do your best!';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: identity.gradient),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: identity.accent.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                  child: Text(identity.emoji,
                      style: const TextStyle(fontSize: 56))),
            ),
            const SizedBox(height: 20),
            Text(moduleName,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (_tier.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: identity.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$_tier level',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: identity.accent,
                          fontWeight: FontWeight.w700,
                        )),
              ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: AppTheme.radiusXl,
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: identity.accent),
                      const SizedBox(width: 6),
                      Text('HOW TO PLAY',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppTheme.textDim, letterSpacing: 1.1)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(how,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(height: 1.4)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text('I\'m ready — Start',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
