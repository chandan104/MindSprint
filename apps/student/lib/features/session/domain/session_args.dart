import 'package:flutter/foundation.dart';

import '../../assessments/domain/assessment_models.dart';

/// Student identity confirmed by the teacher (dialog gate) — carried through
/// setup into the session so results attribute to the right child.
@immutable
class ConfirmedStudent {
  final String studentId;
  final String studentName;
  final String classId;

  const ConfirmedStudent({
    required this.studentId,
    required this.studentName,
    required this.classId,
  });
}

/// Everything a session needs, resolved BEFORE the session starts: the
/// online-required rule applies to session start, and the in-progress
/// session must never wait on the network — so content is fetched during
/// setup and passed in fully materialized.
@immutable
class SessionRunArgs {
  final ConfirmedStudent student;
  final AssessmentLevel level;
  final List<ContentItem> items;

  const SessionRunArgs({
    required this.student,
    required this.level,
    required this.items,
  });
}
