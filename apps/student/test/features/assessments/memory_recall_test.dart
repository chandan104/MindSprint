import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/engine/assessment_module.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';
import 'package:mindsprint_student/features/assessments/memory_recall/memory_recall_module.dart';

/// Captures events in memory so gameplay tests can inspect what was
/// recorded — the event log IS the module's observable contract.
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
  moduleKey: 'memory_recall',
  name: 'Test Level',
  difficulty: 'easy',
  config: {
    'category_key': 'animals',
    'sequence_length': 2,
    'display_time_ms': 300,
    'inter_item_gap_ms': 100,
    'choice_grid_size': 4,
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

  Widget app() => MaterialApp(
        home: Scaffold(
          body: MemoryRecallRunner(
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
      );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
  }

  /// Recorded events (flushed + still buffered) in order.
  Future<List<RecordedEvent>> allEvents() async {
    await recorder.flush();
    return store.saved;
  }

  Future<void> playThroughDisplay(WidgetTester tester) async {
    await tester.tap(find.text('Start'));
    await tester.pump(); // begin display phase
    await tester.pump(const Duration(milliseconds: 300)); // item 1 shown
    await tester.pump(const Duration(milliseconds: 100)); // gap
    await tester.pump(const Duration(milliseconds: 300)); // item 2 shown
    await tester.pump(); // recall phase build
  }

  testWidgets('emits the full display-phase event sequence', (tester) async {
    await pumpApp(tester);
    expect(find.text('Watch carefully!'), findsOneWidget);

    await playThroughDisplay(tester);

    final events = await allEvents();
    final types = events.map((e) => e.eventType).toList();
    expect(types, [
      'sequence_display_started',
      'item_displayed',
      'item_displayed',
      'sequence_hidden',
    ]);

    // The announced sequence and the per-item events must agree — replay
    // depends on payloads being self-contained.
    final announced = (events.first.payload['sequence'] as List)
        .map((e) => (e as Map)['item_id'])
        .toList();
    final displayed = events
        .where((e) => e.eventType == 'item_displayed')
        .map((e) => e.payload['item_id'])
        .toList();
    expect(displayed, announced);
    expect(find.text('Tap them in the same order!'), findsOneWidget);
  });

  testWidgets('correct taps in order complete the assessment', (tester) async {
    await pumpApp(tester);
    await playThroughDisplay(tester);

    final events = await allEvents();
    final sequenceIds = (events.first.payload['sequence'] as List)
        .map((e) => (e as Map)['item_id'] as String)
        .toList();

    for (final id in sequenceIds) {
      await tester.tap(find.byKey(ValueKey('choice-$id')));
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(outcome, AssessmentOutcome.completed);

    final taps = (await allEvents())
        .where((e) => e.eventType == 'tap_registered')
        .toList();
    expect(taps.length, sequenceIds.length);
    expect(taps.every((t) => t.payload['is_correct'] == true), isTrue);
  });

  testWidgets('a wrong tap is recorded as incorrect and does not advance',
      (tester) async {
    await pumpApp(tester);
    await playThroughDisplay(tester);

    final events = await allEvents();
    final sequenceIds = (events.first.payload['sequence'] as List)
        .map((e) => (e as Map)['item_id'] as String)
        .toList();
    final wrongItem = _items.firstWhere((i) => i.id != sequenceIds.first);

    await tester.tap(find.byKey(ValueKey('choice-${wrongItem.id}')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(outcome, isNull, reason: 'wrong tap must not complete anything');
    final taps = (await allEvents())
        .where((e) => e.eventType == 'tap_registered')
        .toList();
    expect(taps.single.payload['is_correct'], false);
    expect(taps.single.payload['item_id'], wrongItem.id);

    // Recovery: correct taps still finish the run.
    for (final id in sequenceIds) {
      await tester.tap(find.byKey(ValueKey('choice-$id')));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(outcome, AssessmentOutcome.completed);
  });

  testWidgets('tap timestamps are strictly increasing', (tester) async {
    await pumpApp(tester);
    await playThroughDisplay(tester);

    final events = await allEvents();
    final sequenceIds = (events.first.payload['sequence'] as List)
        .map((e) => (e as Map)['item_id'] as String)
        .toList();
    for (final id in sequenceIds) {
      await tester.tap(find.byKey(ValueKey('choice-$id')));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final all = await allEvents();
    for (var i = 1; i < all.length; i++) {
      expect(all[i].seq, all[i - 1].seq + 1, reason: 'seq must be dense');
      expect(all[i].tMs, greaterThanOrEqualTo(all[i - 1].tMs),
          reason: 't_ms must be monotonic');
    }
  });
}
