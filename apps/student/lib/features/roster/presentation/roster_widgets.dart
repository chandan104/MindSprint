import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A left-aligned instruction header ("Select a Class", "Select a Student")
/// that gives the roster flow clear, premium guidance.
class RosterHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const RosterHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textDim)),
        ],
      ),
    );
  }
}

/// A friendly, centred empty state — never a blank screen.
class RosterEmpty extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  const RosterEmpty(
      {super.key,
      required this.emoji,
      required this.title,
      required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textDim)),
          ],
        ),
      ),
    );
  }
}
