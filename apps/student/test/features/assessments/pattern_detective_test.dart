import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';
import 'package:mindsprint_student/features/assessments/pattern_recognition/pattern_detective_module.dart';
import 'package:mindsprint_student/features/assessments/pattern_recognition/pattern_generator.dart';

class _CapturingStore implements EventStore {
  final saved = <RecordedEvent>[];
  @override
  Future<void> saveEvents(List<RecordedEvent> events) async =>
      saved.addAll(events);
}

const _items = [
  ContentItem(id: 'circle', label: 'Circle', emoji: '🔵'),
  ContentItem(id: 'square', label: 'Square', emoji: '🟥'),
  ContentItem(id: 'star', label: 'Star', emoji: '⭐'),
  ContentItem(id: 'heart', label: 'Heart', emoji: '❤️'),
];

void main() {
  group('PatternGenerator', () {
    PatternGenerator gen(String kind, {int length = 6, int seed = 1}) =>
        PatternGenerator(
          kinds: [kind],
          sequenceLength: length,
          optionCount: 3,
          pool: _items,
          random: Random(seed),
        );

    test('ab alternates with period 2 and the answer continues the rule', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = gen('ab', seed: seed).next();
        final full = [...q.shown, q.answer];
        for (var i = 2; i < full.length; i++) {
          expect(full[i].id, full[i - 2].id,
              reason: 'ab pattern must repeat with period 2');
        }
      }
    });

    test('abc repeats with period 3', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = gen('abc', seed: seed).next();
        final full = [...q.shown, q.answer];
        for (var i = 3; i < full.length; i++) {
          expect(full[i].id, full[i - 3].id);
        }
      }
    });

    test('aabb repeats with period 4 in pairs', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = gen('aabb', seed: seed, length: 7).next();
        final full = [...q.shown, q.answer];
        for (var i = 4; i < full.length; i++) {
          expect(full[i].id, full[i - 4].id);
        }
        expect(full[0].id, full[1].id, reason: 'starts with a pair');
      }
    });

    test('abb repeats with period 3, one head two tails', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = gen('abb', seed: seed).next();
        final full = [...q.shown, q.answer];
        for (var i = 3; i < full.length; i++) {
          expect(full[i].id, full[i - 3].id);
        }
        expect(full[1].id, full[2].id, reason: 'positions 1,2 are the pair');
      }
    });

    test('mirror sequences are palindromes', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = gen('mirror', seed: seed, length: 6).next();
        final full = [...q.shown, q.answer];
        for (var i = 0; i < full.length; i++) {
          expect(full[i].id, full[full.length - 1 - i].id,
              reason: 'mirror pattern must read the same in both directions');
        }
      }
    });

    test('options contain the answer exactly once with no duplicates', () {
      for (var seed = 0; seed < 100; seed++) {
        final q = PatternGenerator(
          kinds: ['ab', 'abc', 'aabb', 'abb', 'mirror'],
          sequenceLength: 6,
          optionCount: 3,
          pool: _items,
          random: Random(seed),
        ).next();
        expect(q.options.length, 3);
        expect(q.options.map((o) => o.id).toSet().length, 3);
        expect(q.options.where((o) => o.id == q.answer.id).length, 1);
      }
    });
  });

  group('PatternDetectiveRunner', () {
    late _CapturingStore store;
    late SessionRecorder recorder;
    late StopwatchTimingService timing;
    AssessmentOutcome? outcome;

    const level = AssessmentLevel(
      levelId: 'l1',
      levelVersionId: 'lv1',
      version: 1,
      moduleKey: 'pattern_recognition',
      name: 'Test Level',
      difficulty: 'easy',
      config: {
        'category_key': 'shapes',
        'pattern_kinds': ['ab'],
        'question_count': 2,
        'sequence_length': 4,
        'option_count': 2,
        'time_limit_ms_per_question': 5000,
      },
    );

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
          body: PatternDetectiveRunner(
            runContext: AssessmentRunContext(
              level: level,
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

    Future<String> expectedAnswerId() async {
      final events = await allEvents();
      final q = events.lastWhere((e) => e.eventType == 'question_displayed');
      final label = q.payload['expected_answer'] as String;
      final options = (q.payload['options'] as List).cast<Map>();
      return options.firstWhere((o) => o['label'] == label)['item_id']
          as String;
    }

    testWidgets('correct answers complete the assessment with full payloads',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      for (var i = 0; i < 2; i++) {
        final answerId = await expectedAnswerId();
        await tester.tap(find.byKey(ValueKey('pattern-option-$answerId')));
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pump();
      }

      expect(outcome, AssessmentOutcome.completed);
      final events = await allEvents();
      final questions =
          events.where((e) => e.eventType == 'question_displayed').toList();
      expect(questions.length, 2);
      // Self-contained payloads: shown sequence AND options are recorded.
      expect((questions.first.payload['sequence'] as List).length, 3);
      expect((questions.first.payload['options'] as List).length, 2);
      final taps =
          events.where((e) => e.eventType == 'tap_registered').toList();
      expect(taps.every((t) => t.payload['is_correct'] == true), isTrue);
    });

    testWidgets('a wrong answer is measured and the run continues',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      final answerId = await expectedAnswerId();
      final events = await allEvents();
      final options = (events
              .lastWhere((e) => e.eventType == 'question_displayed')
              .payload['options'] as List)
          .cast<Map>();
      final wrongId = options
          .firstWhere((o) => o['item_id'] != answerId)['item_id'] as String;

      await tester.tap(find.byKey(ValueKey('pattern-option-$wrongId')));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();

      final answer2 = await expectedAnswerId();
      await tester.tap(find.byKey(ValueKey('pattern-option-$answer2')));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();

      expect(outcome, AssessmentOutcome.completed);
      final taps = (await allEvents())
          .where((e) => e.eventType == 'tap_registered')
          .toList();
      expect(taps.first.payload['is_correct'], false);
      expect(taps.last.payload['is_correct'], true);
    });
  });
}
