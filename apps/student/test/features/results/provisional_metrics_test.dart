import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/features/results/domain/provisional_metrics.dart';

void main() {
  group('computeProvisionalMetrics', () {
    // Every contract fixture with expected metrics is asserted automatically:
    // adding a fixture extends the drift guard with zero test changes.
    final fixtureFiles = Directory('../../packages/contracts/fixtures')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    for (final file in fixtureFiles) {
      final fixture =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final expected =
          fixture['expected_metrics_v1'] as Map<String, dynamic>?;
      if (expected == null) continue;

      test('reproduces ${file.uri.pathSegments.last} exactly (drift guard)',
          () {
        final events = [
          for (final e in fixture['events'] as List)
            MetricEvent(
              eventType: e['event_type'] as String,
              tMs: e['t_ms'] as int,
              payload: Map<String, Object?>.from(e['payload'] as Map),
            ),
        ];

        final m = computeProvisionalMetrics(events);

        expect(m.totalTimeMs, expected['total_time_ms']);
        expect(m.reactionTimeMs, expected['reaction_time_ms']);
        expect(m.recallTimeMs, expected['recall_time_ms']);
        expect(m.decisionTimesMs, expected['decision_times_ms']);
        expect(m.hesitationCount, expected['hesitation_count']);
        expect(m.totalIdleTimeMs, expected['total_idle_time_ms']);
        expect(m.longestPauseMs, expected['longest_pause_ms']);
        expect(m.correctCount, expected['correct_count']);
        expect(m.errorCount, expected['error_count']);
        expect(m.accuracy, expected['accuracy']);
        expect(m.medianDecisionMs, expected['median_decision_ms']);
        expect(m.fastestDecisionMs, expected['fastest_decision_ms']);
        expect(m.slowestDecisionMs, expected['slowest_decision_ms']);
      });
    }

    test('empty event log yields zeroed metrics, no crashes', () {
      final m = computeProvisionalMetrics(const []);
      expect(m.totalTimeMs, 0);
      expect(m.reactionTimeMs, isNull);
      expect(m.accuracy, isNull);
      expect(m.meanDecisionMs, isNull);
    });

    test('gaps over 3000ms count as hesitations and idle time', () {
      final m = computeProvisionalMetrics(const [
        MetricEvent(eventType: 'session_started', tMs: 0),
        MetricEvent(eventType: 'sequence_display_started', tMs: 100),
        MetricEvent(eventType: 'sequence_hidden', tMs: 500),
        MetricEvent(
            eventType: 'tap_registered',
            tMs: 1000,
            payload: {'is_correct': true}),
        MetricEvent(
            eventType: 'tap_registered',
            tMs: 5500, // 4500ms gap — a hesitation
            payload: {'is_correct': true}),
        MetricEvent(
            eventType: 'tap_registered',
            tMs: 6000,
            payload: {'is_correct': true}),
        MetricEvent(eventType: 'session_completed', tMs: 6200),
      ]);
      expect(m.hesitationCount, 1);
      expect(m.totalIdleTimeMs, 4500);
      expect(m.longestPauseMs, 4500);
      expect(m.decisionTimesMs, [4500, 500]);
      expect(m.reactionTimeMs, 900);
      expect(m.recallTimeMs, 500);
      expect(m.accuracy, 1.0);
    });

    test('boundary: a gap of exactly 3000ms is NOT a hesitation', () {
      final m = computeProvisionalMetrics(const [
        MetricEvent(eventType: 'session_started', tMs: 0),
        MetricEvent(
            eventType: 'tap_registered', tMs: 100, payload: {'is_correct': true}),
        MetricEvent(
            eventType: 'tap_registered',
            tMs: 3100,
            payload: {'is_correct': true}),
        MetricEvent(eventType: 'session_completed', tMs: 3200),
      ]);
      expect(m.hesitationCount, 0);
      expect(m.totalIdleTimeMs, 0);
    });
  });
}
