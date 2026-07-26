import 'package:flutter/foundation.dart';

/// Minimal event view the metrics engine needs — decoupled from Drift rows
/// and recorder types so it can also consume contract fixtures in tests.
@immutable
class MetricEvent {
  final String eventType;
  final int tMs;
  final Map<String, Object?> payload;

  const MetricEvent({
    required this.eventType,
    required this.tMs,
    this.payload = const {},
  });
}

/// Provisional session metrics, computed on-device for the instant result
/// screen. Implements packages/contracts/metrics/v1/definitions.md — the
/// server's canonical engine (Phase 4) implements the SAME definitions and
/// is always authoritative. The shared fixture test is the drift guard.
@immutable
class ProvisionalMetrics {
  static const int metricsVersion = 1;

  /// Hesitation threshold, fixed in v1 (definitions.md).
  static const int hesitationThresholdMs = 3000;

  final int totalTimeMs;

  /// Stimulus visible → first tap. Null when the session had no stimulus or
  /// no taps (e.g. aborted immediately).
  final int? reactionTimeMs;

  /// sequence_hidden → first subsequent tap (memory-recall specific;
  /// null for modules without a hide phase).
  final int? recallTimeMs;

  /// First instruction_shown → first stimulus (Color Selector's
  /// instruction-reading delay); null for modules without instructions.
  final int? instructionDelayMs;

  /// Stroop interference: mean reaction time on incongruent trials − mean on
  /// congruent trials (correct responses only), in ms. Null unless the session
  /// has congruency-tagged trials of both kinds. Higher = more interference.
  final int? stroopInterferenceMs;

  /// Gaps between consecutive answer taps.
  final List<int> decisionTimesMs;

  final int hesitationCount;
  final int totalIdleTimeMs;
  final int? longestPauseMs;

  final int correctCount;
  final int errorCount;

  const ProvisionalMetrics({
    required this.totalTimeMs,
    required this.reactionTimeMs,
    required this.recallTimeMs,
    required this.instructionDelayMs,
    required this.decisionTimesMs,
    required this.hesitationCount,
    required this.totalIdleTimeMs,
    required this.longestPauseMs,
    required this.correctCount,
    required this.errorCount,
    this.stroopInterferenceMs,
  });

  int get totalAnswers => correctCount + errorCount;

  /// correct ÷ total answers; null when nothing was answered.
  double? get accuracy =>
      totalAnswers == 0 ? null : correctCount / totalAnswers;

  int? get fastestDecisionMs =>
      decisionTimesMs.isEmpty ? null : decisionTimesMs.reduce((a, b) => a < b ? a : b);

  int? get slowestDecisionMs =>
      decisionTimesMs.isEmpty ? null : decisionTimesMs.reduce((a, b) => a > b ? a : b);

  double? get meanDecisionMs => decisionTimesMs.isEmpty
      ? null
      : decisionTimesMs.reduce((a, b) => a + b) / decisionTimesMs.length;

  double? get medianDecisionMs {
    if (decisionTimesMs.isEmpty) return null;
    final sorted = [...decisionTimesMs]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  Map<String, Object?> toJson() => {
        'metrics_version': metricsVersion,
        'total_time_ms': totalTimeMs,
        'reaction_time_ms': reactionTimeMs,
        'recall_time_ms': recallTimeMs,
        'decision_times_ms': decisionTimesMs,
        'hesitation_count': hesitationCount,
        'total_idle_time_ms': totalIdleTimeMs,
        'longest_pause_ms': longestPauseMs,
        'correct_count': correctCount,
        'error_count': errorCount,
        'accuracy': accuracy,
        'mean_decision_ms': meanDecisionMs,
        'median_decision_ms': medianDecisionMs,
        'fastest_decision_ms': fastestDecisionMs,
        'slowest_decision_ms': slowestDecisionMs,
        'instruction_delay_ms': instructionDelayMs,
        'stroop_interference_ms': stroopInterferenceMs,
      };
}

const _stimulusEvents = {'sequence_display_started', 'question_displayed'};

/// Computes provisional metrics from an ordered event log. Pure function:
/// same events in, same metrics out, no clock or I/O — identical inputs to
/// what the server-side engine will receive.
ProvisionalMetrics computeProvisionalMetrics(List<MetricEvent> events) {
  if (events.isEmpty) {
    return const ProvisionalMetrics(
      totalTimeMs: 0,
      reactionTimeMs: null,
      recallTimeMs: null,
      instructionDelayMs: null,
      decisionTimesMs: [],
      hesitationCount: 0,
      totalIdleTimeMs: 0,
      longestPauseMs: null,
      correctCount: 0,
      errorCount: 0,
      stroopInterferenceMs: null,
    );
  }

  final start = events.first.tMs;
  final end = events.last.tMs;

  int? firstStimulusT;
  int? sequenceHiddenT;
  int? instructionT;
  int? reaction;
  int? recall;
  final taps = <MetricEvent>[];
  var correct = 0;
  var errors = 0;

  // Stroop interference: pair each congruency-tagged question with its next
  // tap's reaction time (question → tap), split by congruency, correct only.
  int? currentQuestionT;
  bool? currentCongruent;
  final congruentRts = <int>[];
  final incongruentRts = <int>[];

  for (final event in events) {
    if (_stimulusEvents.contains(event.eventType)) {
      firstStimulusT ??= event.tMs;
      if (event.eventType == 'question_displayed') {
        currentQuestionT = event.tMs;
        final c = event.payload['congruent'];
        currentCongruent = c is bool ? c : null;
      }
    } else if (event.eventType == 'instruction_shown') {
      instructionT ??= event.tMs;
    } else if (event.eventType == 'sequence_hidden') {
      sequenceHiddenT ??= event.tMs;
    } else if (event.eventType == 'tap_registered') {
      taps.add(event);
      if (firstStimulusT != null && reaction == null) {
        reaction = event.tMs - firstStimulusT;
      }
      if (sequenceHiddenT != null && recall == null) {
        recall = event.tMs - sequenceHiddenT;
      }
      final isCorrect = event.payload['is_correct'];
      if (isCorrect == true) correct++;
      if (isCorrect == false) errors++;
      if (currentCongruent != null &&
          currentQuestionT != null &&
          isCorrect == true) {
        final rt = event.tMs - currentQuestionT;
        (currentCongruent ? congruentRts : incongruentRts).add(rt);
      }
      // Each response consumes its question's congruency tag.
      currentCongruent = null;
      currentQuestionT = null;
    } else if (event.eventType == 'answer_submitted') {
      final isCorrect = event.payload['is_correct'];
      if (isCorrect == true) correct++;
      if (isCorrect == false) errors++;
      currentCongruent = null;
      currentQuestionT = null;
    }
  }

  int? interference;
  if (congruentRts.isNotEmpty && incongruentRts.isNotEmpty) {
    final meanCong = congruentRts.reduce((a, b) => a + b) / congruentRts.length;
    final meanIncong =
        incongruentRts.reduce((a, b) => a + b) / incongruentRts.length;
    interference = (meanIncong - meanCong).round();
  }

  final decisions = <int>[];
  for (var i = 1; i < taps.length; i++) {
    decisions.add(taps[i].tMs - taps[i - 1].tMs);
  }

  var hesitations = 0;
  var idle = 0;
  for (final gap in decisions) {
    if (gap > ProvisionalMetrics.hesitationThresholdMs) {
      hesitations++;
      idle += gap;
    }
  }

  return ProvisionalMetrics(
    totalTimeMs: end - start,
    reactionTimeMs: reaction,
    recallTimeMs: recall,
    instructionDelayMs: (instructionT != null && firstStimulusT != null)
        ? firstStimulusT - instructionT
        : null,
    decisionTimesMs: decisions,
    hesitationCount: hesitations,
    totalIdleTimeMs: idle,
    longestPauseMs: decisions.isEmpty ? null : decisions.reduce((a, b) => a > b ? a : b),
    correctCount: correct,
    errorCount: errors,
    stroopInterferenceMs: interference,
  );
}
