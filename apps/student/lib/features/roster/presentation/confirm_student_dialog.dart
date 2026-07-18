import 'package:flutter/material.dart';

import '../domain/roster_models.dart';

/// Mandatory confirmation before a session starts. Returns true only when the
/// teacher explicitly confirms the student identity.
Future<bool> showConfirmStudentDialog(BuildContext context, Student student) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Start assessment?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(
              student.fullName.characters.first,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            student.fullName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (student.rollNumber != null)
            Text('Roll ${student.rollNumber}',
                style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          const Text(
            'Confirm this is the student holding the device.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Start'),
        ),
      ],
    ),
  );
  return result ?? false;
}
