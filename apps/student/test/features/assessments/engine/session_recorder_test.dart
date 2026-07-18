import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';
import 'package:mocktail/mocktail.dart';

class _MockEventStore extends Mock implements EventStore {}

/// Deterministic clock for recorder tests.
class _FakeTiming implements TimingService {
  int current = 0;

  @override
  void start() {}

  @override
  bool get isRunning => true;

  @override
  int get nowMs => current;

  @override
  DateTime get sessionStartWallClock => DateTime(2026, 7, 18);
}

void main() {
  late _MockEventStore store;
  late _FakeTiming timing;

  setUp(() {
    store = _MockEventStore();
    timing = _FakeTiming();
    when(() => store.saveEvents(any())).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(<RecordedEvent>[]);
  });

  SessionRecorder buildRecorder() => SessionRecorder(
        sessionId: 'session-1',
        timing: timing,
        store: store,
      );

  group('SessionRecorder', () {
    test('seq starts at 1 and increases strictly', () async {
      final recorder = buildRecorder();
      final first = recorder.record('session_started');
      timing.current = 10;
      final second = recorder.record('tap_registered', {'x': 1, 'y': 2});
      final third = recorder.record('tap_registered', {'x': 3, 'y': 4});

      expect(first.seq, 1);
      expect(second.seq, 2);
      expect(third.seq, 3);
      await recorder.dispose();
    });

    test('events carry the monotonic timestamp at record time', () async {
      final recorder = buildRecorder();
      timing.current = 1234;
      final event = recorder.record('sequence_hidden');
      expect(event.tMs, 1234);
      expect(event.sessionId, 'session-1');
      await recorder.dispose();
    });

    test('record buffers without writing; flush writes the batch in order',
        () async {
      final recorder = buildRecorder();
      recorder.record('session_started');
      recorder.record('tap_registered', {'x': 1.0, 'y': 2.0});
      verifyNever(() => store.saveEvents(any()));

      await recorder.flush();

      final captured =
          verify(() => store.saveEvents(captureAny())).captured.single
              as List<RecordedEvent>;
      expect(captured.map((e) => e.seq), [1, 2]);
      expect(captured.map((e) => e.eventType),
          ['session_started', 'tap_registered']);
      await recorder.dispose();
    });

    test('flush with empty buffer does not touch the store', () async {
      final recorder = buildRecorder();
      await recorder.flush();
      verifyNever(() => store.saveEvents(any()));
      await recorder.dispose();
    });

    test('periodic timer flushes the buffer automatically', () {
      fakeAsync((async) {
        final recorder = buildRecorder();
        recorder.record('session_started');
        verifyNever(() => store.saveEvents(any()));

        async.elapse(const Duration(milliseconds: 600));
        verify(() => store.saveEvents(any())).called(1);

        recorder.dispose();
        async.flushMicrotasks();
      });
    });

    test('recordAndFlush persists immediately', () async {
      final recorder = buildRecorder();
      await recorder.recordAndFlush('session_completed');
      verify(() => store.saveEvents(any())).called(1);
      await recorder.dispose();
    });

    test('dispose flushes remaining events and forbids further use', () async {
      final recorder = buildRecorder();
      recorder.record('session_started');
      await recorder.dispose();

      verify(() => store.saveEvents(any())).called(1);
      expect(() => recorder.record('tap_registered'), throwsStateError);
    });
  });
}
