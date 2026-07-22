import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';
import 'package:mindsprint_student/features/assessments/sequence_logic/sequence_logic_module.dart';
import 'package:mindsprint_student/features/assessments/sequence_logic/series_generator.dart';

class _CapturingStore implements EventStore {
  final saved = <RecordedEvent>[];
  @override
  Future<void> saveEvents(List<RecordedEvent> events) async =>
      saved.addAll(events);
}

const _level = AssessmentLevel(
  levelId: 'l1',
  levelVersionId: 'lv1',
  version: 1,
  moduleKey: 'sequence_logic',
  name: 'Test Level',
  difficulty: 'easy',
  config: {
    'category_key': 'numbers',
    'logic_kinds': ['next_in_series'],
    'question_count': 2,
    'sequence_length': 4,
    'time_limit_ms_per_question': 5000,
  },
);

void main() {
  group('SeriesGenerator', () {
    test('next_in_series follows a constant arithmetic step', () {
      final gen = SeriesGenerator(
          kinds: ['next_in_series'], sequenceLength: 4, random: Random(1));
      for (var i = 0; i < 200; i++) {
        final q = gen.next();
        final full = [...q.shown, q.answer];
        final step = full[1] - full[0];
        for (var j = 1; j < full.length; j++) {
          expect(full[j] - full[j - 1], step,
              reason: 'series must have a constant step');
        }
      }
    });

    test('reverse_order descends and stays non-negative', () {
      final gen = SeriesGenerator(
          kinds: ['reverse_order'], sequenceLength: 4, random: Random(2));
      for (var i = 0; i < 200; i++) {
        final q = gen.next();
        final full = [...q.shown, q.answer];
        for (var j = 1; j < full.length; j++) {
          expect(full[j], lessThan(full[j - 1]));
        }
        expect(full.every((n) => n >= 0), isTrue);
      }
    });

    test('options contain the answer exactly once, distinct, non-negative', () {
      final gen = SeriesGenerator(
          kinds: ['next_in_series', 'reverse_order'],
          sequenceLength: 5,
          random: Random(3));
      for (var i = 0; i < 300; i++) {
        final q = gen.next();
        expect(q.options.length, SeriesGenerator.optionCount);
        expect(q.options.toSet().length, q.options.length);
        expect(q.options.where((o) => o == q.answer).length, 1);
        expect(q.options.every((o) => o >= 0), isTrue);
      }
    });
  });

  group('SequenceLogicRunner', () {
    late _CapturingStore store;
    late SessionRecorder recorder;
    late StopwatchTimingService timing;
    AssessmentOutcome? outcome;

    setUp(() {
      store = _CapturingStore();
      timing = StopwatchTimingService()..start();
      recorder =
          SessionRecorder(sessionId: 's1', timing: timing, store: store);
      outcome = null;
    });

    tearDown(() => recorder.dispose());

    Future<List<RecordedEvent>> allEvents() async {
      await recorder.flush();
      return store.saved;
    }

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SequenceLogicRunner(
            runContext: AssessmentRunContext(
              level: _level,
              items: const [],
              recorder: recorder,
              timing: timing,
              onFinished: (o) => outcome = o,
            ),
            random: Random(42),
          ),
        ),
      ));
    }

    Future<int> expectedAnswer() async {
      final events = await allEvents();
      final q = events.lastWhere((e) => e.eventType == 'question_displayed');
      return int.parse(q.payload['expected_answer'] as String);
    }

    testWidgets('correct answers complete the assessment with full payloads',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      for (var i = 0; i < 2; i++) {
        final answer = await expectedAnswer();
        await tester.tap(find.byKey(ValueKey('series-option-$answer')));
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pump();
      }

      expect(outcome, AssessmentOutcome.completed);
      final events = await allEvents();
      final questions =
          events.where((e) => e.eventType == 'question_displayed').toList();
      expect(questions.length, 2);
      expect((questions.first.payload['sequence'] as List).length, 3);
      expect((questions.first.payload['options'] as List).length, 3);
      final taps =
          events.where((e) => e.eventType == 'tap_registered').toList();
      expect(taps.every((t) => t.payload['is_correct'] == true), isTrue);
    });

    testWidgets('a timeout records a measured miss and advances',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 5100));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();

      final events = await allEvents();
      final miss =
          events.where((e) => e.eventType == 'answer_submitted').toList();
      expect(miss.single.payload['is_correct'], false);
      expect(miss.single.payload['answer'], 'timeout');

      final answer2 = await expectedAnswer();
      await tester.tap(find.byKey(ValueKey('series-option-$answer2')));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();
      expect(outcome, AssessmentOutcome.completed);
    });
  });
}
