import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';
import 'package:mindsprint_student/features/assessments/visual_search/visual_search_module.dart';

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
  ContentItem(id: 'panda', label: 'Panda', emoji: '🐼'),
  ContentItem(id: 'fox', label: 'Fox', emoji: '🦊'),
];

const _level = AssessmentLevel(
  levelId: 'l1',
  levelVersionId: 'lv1',
  version: 1,
  moduleKey: 'visual_search',
  name: 'Test Level',
  difficulty: 'easy',
  config: {
    'category_key': 'animals',
    'trial_count': 2,
    'grid_size': 6,
    'target_present_ratio': 1.0, // deterministic: target always present
    'time_limit_ms_per_trial': 5000,
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

  Future<void> pumpApp(WidgetTester tester, {double ratio = 1.0}) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final level = AssessmentLevel(
      levelId: _level.levelId,
      levelVersionId: _level.levelVersionId,
      version: _level.version,
      moduleKey: _level.moduleKey,
      name: _level.name,
      difficulty: _level.difficulty,
      config: {..._level.config, 'target_present_ratio': ratio},
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisualSearchRunner(
          runContext: AssessmentRunContext(
            level: level,
            items: _items,
            recorder: recorder,
            timing: timing,
            onFinished: (o) => outcome = o,
          ),
          random: Random(7),
        ),
      ),
    ));
  }

  Future<List<RecordedEvent>> allEvents() async {
    await recorder.flush();
    return store.saved;
  }

  testWidgets('finding the target correctly is recorded and completes',
      (tester) async {
    await pumpApp(tester, ratio: 1.0);
    await tester.tap(find.text('Start'));
    await tester.pump();

    for (var i = 0; i < 2; i++) {
      final events = await allEvents();
      final q = events.lastWhere((e) => e.eventType == 'question_displayed');
      final expectedLabel = q.payload['expected_answer'] as String;
      final options = (q.payload['options'] as List).cast<Map>();
      final expectedId = options
          .firstWhere((o) => o['label'] == expectedLabel)['item_id'] as String;
      await tester.tap(find.byKey(ValueKey('cell-$expectedId')));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();
    }

    expect(outcome, AssessmentOutcome.completed);
    final events = await allEvents();
    final questions =
        events.where((e) => e.eventType == 'question_displayed').toList();
    expect(questions.length, 2);
    // Self-contained payload: grid (6) + the "Not here!" sentinel = 7.
    expect((questions.first.payload['options'] as List).length, 7);
    final taps = events.where((e) => e.eventType == 'tap_registered').toList();
    expect(taps.every((t) => t.payload['is_correct'] == true), isTrue);
  });

  testWidgets('target-absent trial: tapping "Not here!" is correct',
      (tester) async {
    await pumpApp(tester, ratio: 0.0); // deterministic: never present
    await tester.tap(find.text('Start'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('cell-not_present')));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    final events = await allEvents();
    final tap = events.firstWhere((e) => e.eventType == 'tap_registered');
    expect(tap.payload['item_id'], 'not_present');
    expect(tap.payload['is_correct'], true);
  });

  testWidgets('tapping a wrong grid item on an absent-target trial is measured',
      (tester) async {
    await pumpApp(tester, ratio: 0.0);
    await tester.tap(find.text('Start'));
    await tester.pump();

    final events = await allEvents();
    final q = events.lastWhere((e) => e.eventType == 'question_displayed');
    final options = (q.payload['options'] as List).cast<Map>();
    final wrongId = options
        .firstWhere((o) => o['item_id'] != 'not_present')['item_id'] as String;

    await tester.tap(find.byKey(ValueKey('cell-$wrongId')));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    final tap = (await allEvents()).firstWhere((e) => e.eventType == 'tap_registered');
    expect(tap.payload['is_correct'], false);
  });

  testWidgets('a timeout records a measured miss and advances', (tester) async {
    await pumpApp(tester, ratio: 1.0);
    await tester.tap(find.text('Start'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    final events = await allEvents();
    final miss = events.where((e) => e.eventType == 'answer_submitted').toList();
    expect(miss.single.payload['is_correct'], false);
    expect(miss.single.payload['answer'], 'timeout');

    final q2 = events.lastWhere((e) => e.eventType == 'question_displayed');
    final expectedLabel2 = q2.payload['expected_answer'] as String;
    final options2 = (q2.payload['options'] as List).cast<Map>();
    final expectedId2 = options2
        .firstWhere((o) => o['label'] == expectedLabel2)['item_id'] as String;
    await tester.tap(find.byKey(ValueKey('cell-$expectedId2')));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(outcome, AssessmentOutcome.completed);
  });
}
