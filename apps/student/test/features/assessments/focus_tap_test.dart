import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/attention_focus/focus_tap_module.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';

class _CapturingStore implements EventStore {
  final saved = <RecordedEvent>[];
  @override
  Future<void> saveEvents(List<RecordedEvent> events) async =>
      saved.addAll(events);
}

const _items = [
  ContentItem(id: 'cat', label: 'Cat', emoji: '🐱'),
  ContentItem(id: 'dog', label: 'Dog', emoji: '🐶'),
  ContentItem(id: 'lion', label: 'Lion', emoji: '🦁'),
  ContentItem(id: 'tiger', label: 'Tiger', emoji: '🐯'),
];

const _level = AssessmentLevel(
  levelId: 'l1',
  levelVersionId: 'lv1',
  version: 1,
  moduleKey: 'attention_focus',
  name: 'Test Level',
  difficulty: 'easy',
  config: {
    'category_key': 'animals',
    'stimulus_count': 4,
    'target_ratio': 0.5,
    'display_time_ms': 400,
    'inter_stimulus_gap_ms': 200,
  },
);

void main() {
  late _CapturingStore store;
  late SessionRecorder recorder;
  late StopwatchTimingService timing;
  AssessmentOutcome? outcome;

  setUp(() {
    store = _CapturingStore();
    timing = StopwatchTimingService()..start();
    recorder = SessionRecorder(sessionId: 's1', timing: timing, store: store);
    outcome = null;
  });

  tearDown(() => recorder.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FocusTapRunner(
          runContext: AssessmentRunContext(
            level: _level,
            items: _items,
            recorder: recorder,
            timing: timing,
            onFinished: (o) => outcome = o,
          ),
          random: Random(42),
        ),
      ),
    ));
  }

  Future<List<RecordedEvent>> allEvents() async {
    await recorder.flush();
    return store.saved;
  }

  Future<bool> currentStimulusIsTarget() async {
    final events = await allEvents();
    final last =
        events.lastWhere((e) => e.eventType == 'item_displayed');
    return last.payload['is_target'] as bool;
  }

  /// Advances through one stimulus window (400ms) + gap (200ms).
  Future<void> passWindow(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }

  testWidgets(
      'tapping every target and passing every distractor is all-correct',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      if (await currentStimulusIsTarget()) {
        await tester.tap(find.byKey(const ValueKey('stimulus-surface')));
        await tester.pump();
      }
      await passWindow(tester);
    }

    expect(outcome, AssessmentOutcome.completed);
    final events = await allEvents();
    final responses = events
        .where((e) =>
            e.eventType == 'tap_registered' ||
            e.eventType == 'answer_submitted')
        .toList();
    expect(responses.length, 4, reason: 'exactly one response per stimulus');
    expect(
        responses.every((r) => r.payload['is_correct'] == true), isTrue);
    final passes = responses
        .where((r) => r.payload['answer'] == 'pass')
        .length;
    expect(passes, greaterThanOrEqualTo(1),
        reason: 'correct rejections are recorded, not skipped');
  });

  testWidgets('commission and omission errors are both measured',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();

    var missedATarget = false;
    var tappedADistractor = false;
    for (var i = 0; i < 4; i++) {
      final isTarget = await currentStimulusIsTarget();
      if (isTarget && !missedATarget) {
        missedATarget = true; // deliberately withhold: omission
      } else if (!isTarget && !tappedADistractor) {
        tappedADistractor = true; // deliberately tap: commission
        await tester.tap(find.byKey(const ValueKey('stimulus-surface')));
        await tester.pump();
      } else if (isTarget) {
        await tester.tap(find.byKey(const ValueKey('stimulus-surface')));
        await tester.pump();
      }
      await passWindow(tester);
    }

    expect(outcome, AssessmentOutcome.completed);
    final events = await allEvents();
    final misses = events.where((e) =>
        e.eventType == 'answer_submitted' && e.payload['answer'] == 'miss');
    final commissions = events.where((e) =>
        e.eventType == 'tap_registered' && e.payload['is_correct'] == false);
    expect(misses.length, 1, reason: 'the withheld target is an omission');
    expect(commissions.length, 1,
        reason: 'the tapped distractor is a commission error');
  });

  testWidgets('only the first tap in a window is recorded', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('stimulus-surface')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stimulus-surface')));
    await tester.pump();

    final events = await allEvents();
    expect(
        events.where((e) => e.eventType == 'tap_registered').length, 1);
  });
}
