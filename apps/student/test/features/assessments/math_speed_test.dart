import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';
import 'package:mindsprint_student/features/assessments/math_speed/math_speed_module.dart';
import 'package:mindsprint_student/features/assessments/math_speed/question_generator.dart';

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
  moduleKey: 'math_speed',
  name: 'Test Level',
  difficulty: 'easy',
  config: {
    'operations': ['add'],
    'question_count': 2,
    'operand_min': 1,
    'operand_max': 9,
    'time_limit_ms_per_question': 5000,
  },
);

void main() {
  group('MathQuestionGenerator', () {
    test('subtraction never yields negative answers', () {
      final generator = MathQuestionGenerator(
          operations: ['sub'], operandMin: 1, operandMax: 20, random: Random(1));
      for (var i = 0; i < 500; i++) {
        expect(generator.next().answer, greaterThanOrEqualTo(0));
      }
    });

    test('division always divides exactly', () {
      final generator = MathQuestionGenerator(
          operations: ['div'], operandMin: 1, operandMax: 12, random: Random(2));
      for (var i = 0; i < 500; i++) {
        final question = generator.next();
        final parts = question.text.split(' ÷ ');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        expect(a % b, 0, reason: '${question.text} must divide exactly');
        expect(a ~/ b, question.answer);
      }
    });

    test('options contain the answer exactly once, all distinct, all >= 0',
        () {
      final generator = MathQuestionGenerator(
          operations: ['add', 'sub', 'mul', 'div'],
          operandMin: 0,
          operandMax: 10,
          random: Random(3));
      for (var i = 0; i < 500; i++) {
        final question = generator.next();
        expect(question.options.length, MathQuestionGenerator.optionCount);
        expect(question.options.toSet().length, question.options.length);
        expect(question.options.where((o) => o == question.answer).length, 1);
        expect(question.options.every((o) => o >= 0), isTrue);
      }
    });

    test('deterministic under a seeded Random', () {
      MathQuestion gen(int seed) => MathQuestionGenerator(
              operations: ['add'],
              operandMin: 1,
              operandMax: 9,
              random: Random(seed))
          .next();
      expect(gen(42).text, gen(42).text);
      expect(gen(42).options, gen(42).options);
    });
  });

  group('MathSpeedRunner', () {
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
          body: MathSpeedRunner(
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

    /// Reads the current question from the latest question_displayed event —
    /// the event log is the source of truth for what is on screen.
    Future<({String text, int answer})> currentQuestion() async {
      final events = await allEvents();
      final q =
          events.lastWhere((e) => e.eventType == 'question_displayed');
      return (
        text: q.payload['question_text'] as String,
        answer: int.parse(q.payload['expected_answer'] as String),
      );
    }

    testWidgets('answering all questions correctly completes the assessment',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      for (var i = 0; i < 2; i++) {
        final question = await currentQuestion();
        await tester
            .tap(find.byKey(ValueKey('answer-${question.answer}')));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();
      }

      expect(outcome, AssessmentOutcome.completed);
      final taps = (await allEvents())
          .where((e) => e.eventType == 'tap_registered')
          .toList();
      expect(taps.length, 2);
      expect(taps.every((t) => t.payload['is_correct'] == true), isTrue);
    });

    testWidgets('a wrong answer is recorded and the run still completes',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Question 1: tap a wrong option deliberately.
      final q1 = await currentQuestion();
      final events = await allEvents();
      final options = ((events
                  .lastWhere((e) => e.eventType == 'question_displayed')
                  .payload['options']) as List)
          .map((o) => int.parse((o as Map)['label'] as String))
          .toList();
      final wrong = options.firstWhere((o) => o != q1.answer);
      await tester.tap(find.byKey(ValueKey('answer-$wrong')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      // Question 2: correct.
      final q2 = await currentQuestion();
      await tester.tap(find.byKey(ValueKey('answer-${q2.answer}')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      expect(outcome, AssessmentOutcome.completed);
      final taps = (await allEvents())
          .where((e) => e.eventType == 'tap_registered')
          .toList();
      expect(taps.first.payload['is_correct'], false);
      expect(taps.last.payload['is_correct'], true);
    });

    testWidgets('a timeout records a measured miss and advances',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Let question 1 time out (5000ms limit).
      await tester.pump(const Duration(milliseconds: 5100));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      final events = await allEvents();
      final miss =
          events.where((e) => e.eventType == 'answer_submitted').toList();
      expect(miss.single.payload['is_correct'], false);
      expect(miss.single.payload['answer'], 'timeout');

      // Question 2 is live; answer it to finish.
      final q2 = await currentQuestion();
      await tester.tap(find.byKey(ValueKey('answer-${q2.answer}')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(outcome, AssessmentOutcome.completed);
    });
  });
}
