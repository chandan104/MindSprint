import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/color_selector/color_selector_module.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';

class _CapturingStore implements EventStore {
  final saved = <RecordedEvent>[];
  @override
  Future<void> saveEvents(List<RecordedEvent> events) async =>
      saved.addAll(events);
}

AssessmentLevel _level({bool stroop = false, List<String>? modes}) =>
    AssessmentLevel(
      levelId: 'l1',
      levelVersionId: 'lv1',
      version: 1,
      moduleKey: 'color_selector',
      name: 'Test Level',
      difficulty: 'easy',
      config: {
        'colour_count': 3,
        'time_limit_ms_per_round': 5000,
        'stroop': stroop,
        'instruction_modes': modes ?? ['colour'],
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

  Future<void> pumpApp(
    WidgetTester tester, {
    bool stroop = false,
    List<String>? modes,
    int roundCount = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ColorSelectorRunner(
          runContext: AssessmentRunContext(
            level: _level(stroop: stroop, modes: modes),
            items: const [],
            recorder: recorder,
            timing: timing,
            onFinished: (o) => outcome = o,
          ),
          random: Random(7),
          roundCount: roundCount,
        ),
      ),
    ));
    await tester.pump(); // build first instruction
  }

  Future<List<RecordedEvent>> allEvents() async {
    await recorder.flush();
    return store.saved;
  }

  /// Taps the tile whose option id equals the round's expected answer.
  Future<void> tapCorrect(WidgetTester tester) async {
    final q = (await allEvents())
        .lastWhere((e) => e.eventType == 'question_displayed');
    final expected = q.payload['expected_answer'] as String;
    final options = (q.payload['options'] as List).cast<Map>();
    final index = options.indexWhere((o) => o['item_id'] == expected);
    await tester.tap(find.byKey(ValueKey('colour-$index')));
    await tester.pump();
  }

  testWidgets('emits instruction_shown before the grid, then question_displayed',
      (tester) async {
    await pumpApp(tester);

    var events = await allEvents();
    // Instruction is shown immediately; the grid is still hidden.
    expect(events.where((e) => e.eventType == 'instruction_shown').length, 1);
    expect(events.any((e) => e.eventType == 'question_displayed'), isFalse);
    final instr = events.firstWhere((e) => e.eventType == 'instruction_shown');
    expect(instr.payload['instruction_kind'], 'colour');
    expect(instr.payload['instruction_text'], isNotEmpty);

    // After the reading beat the options appear.
    await tester.pump(const Duration(milliseconds: 1200));
    events = await allEvents();
    final q = events.firstWhere((e) => e.eventType == 'question_displayed');
    expect((q.payload['options'] as List).length, 3);
  });

  testWidgets('a correct tap is recorded and the run completes',
      (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 1200));

    await tapCorrect(tester);
    await tester.pump(const Duration(milliseconds: 700)); // feedback beat
    await tester.pump();

    expect(outcome, AssessmentOutcome.completed);
    final taps =
        (await allEvents()).where((e) => e.eventType == 'tap_registered');
    expect(taps.single.payload['is_correct'], true);
  });

  testWidgets('a wrong tap is measured as incorrect', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 1200));

    final q = (await allEvents())
        .lastWhere((e) => e.eventType == 'question_displayed');
    final expected = q.payload['expected_answer'] as String;
    final options = (q.payload['options'] as List).cast<Map>();
    final wrongIndex = options.indexWhere((o) => o['item_id'] != expected);
    await tester.tap(find.byKey(ValueKey('colour-$wrongIndex')));
    await tester.pump();

    final tap = (await allEvents())
        .firstWhere((e) => e.eventType == 'tap_registered');
    expect(tap.payload['is_correct'], false);
  });

  testWidgets('a timeout records a measured miss and advances', (tester) async {
    await pumpApp(tester, roundCount: 2);
    await tester.pump(const Duration(milliseconds: 1200));

    // Let the per-round timer elapse without tapping.
    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump(const Duration(milliseconds: 700)); // feedback beat
    await tester.pump();

    final miss = (await allEvents())
        .where((e) => e.eventType == 'answer_submitted')
        .toList();
    expect(miss.single.payload['answer'], 'timeout');
    expect(miss.single.payload['is_correct'], false);

    // A second instruction beat begins the next round.
    expect(
        (await allEvents())
            .where((e) => e.eventType == 'instruction_shown')
            .length,
        2);
  });

  testWidgets('Stroop rounds tag congruency and produce both kinds',
      (tester) async {
    // Over many rounds the controlled ~1/3 congruent mix must yield both a
    // congruent and an incongruent trial, each tagged on question_displayed.
    await pumpApp(tester, stroop: true, modes: ['word'], roundCount: 20);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 1200));
      final q = (await allEvents())
          .lastWhere((e) => e.eventType == 'question_displayed');
      final expected = q.payload['expected_answer'] as String;
      final options = (q.payload['options'] as List).cast<Map>();
      final index = options.indexWhere((o) => o['item_id'] == expected);
      await tester.tap(find.byKey(ValueKey('colour-$index')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }
    final flags = (await allEvents())
        .where((e) => e.eventType == 'question_displayed')
        .map((e) => e.payload['congruent'])
        .toList();
    expect(flags.every((f) => f is bool), isTrue,
        reason: 'every Stroop trial is tagged with congruency');
    expect(flags.contains(true), isTrue);
    expect(flags.contains(false), isTrue);
  });

  testWidgets('Stroop word instruction matches by the word, not the ink',
      (tester) async {
    await pumpApp(tester, stroop: true, modes: ['word']);
    await tester.pump(const Duration(milliseconds: 1200));

    final events = await allEvents();
    final instr = events.firstWhere((e) => e.eventType == 'instruction_shown');
    expect(instr.payload['instruction_kind'], 'word');
    expect(instr.payload['instruction_text'], startsWith('Tap the WORD'));

    // Exactly one option carries the target id — the drift-free match rule.
    final q = events.firstWhere((e) => e.eventType == 'question_displayed');
    final expected = q.payload['expected_answer'] as String;
    final options = (q.payload['options'] as List).cast<Map>();
    expect(options.where((o) => o['item_id'] == expected).length, 1);

    await tapCorrect(tester);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    final tap = (await allEvents())
        .firstWhere((e) => e.eventType == 'tap_registered');
    expect(tap.payload['is_correct'], true);
  });
}
