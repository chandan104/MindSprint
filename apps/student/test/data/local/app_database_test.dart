import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/data/local/app_database.dart';
import 'package:mindsprint_student/features/assessments/engine/session_recorder.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('LocalEvents', () {
    test('insert and read back ordered by seq', () async {
      await db.insertEvents([
        for (final seq in [3, 1, 2])
          LocalEventsCompanion(
            sessionId: const Value('s1'),
            seq: Value(seq),
            eventType: const Value('tap_registered'),
            tMs: Value(seq * 100),
            payloadJson: const Value('{}'),
          ),
      ]);

      final events = await db.eventsForSession('s1');
      expect(events.map((e) => e.seq), [1, 2, 3]);
      expect(events.first.tMs, 100);
    });

    test('re-inserting the same (session, seq) upserts instead of throwing',
        () async {
      final row = LocalEventsCompanion(
        sessionId: const Value('s1'),
        seq: const Value(1),
        eventType: const Value('session_started'),
        tMs: const Value(0),
        payloadJson: const Value('{}'),
      );
      await db.insertEvents([row]);
      await db.insertEvents([row.copyWith(tMs: const Value(5))]);

      final events = await db.eventsForSession('s1');
      expect(events, hasLength(1));
      expect(events.single.tMs, 5);
    });

    test('sessions are isolated and deletable', () async {
      await db.insertEvents([
        const LocalEventsCompanion(
          sessionId: Value('s1'),
          seq: Value(1),
          eventType: Value('session_started'),
          tMs: Value(0),
          payloadJson: Value('{}'),
        ),
        const LocalEventsCompanion(
          sessionId: Value('s2'),
          seq: Value(1),
          eventType: Value('session_started'),
          tMs: Value(0),
          payloadJson: Value('{}'),
        ),
      ]);

      await db.deleteEventsForSession('s1');
      expect(await db.eventsForSession('s1'), isEmpty);
      expect(await db.eventsForSession('s2'), hasLength(1));
    });
  });

  group('DriftEventStore', () {
    test('persists recorder events with JSON payloads', () async {
      final store = DriftEventStore(db);
      await store.saveEvents(const [
        RecordedEvent(
          sessionId: 's1',
          seq: 1,
          eventType: 'tap_registered',
          tMs: 42,
          payload: {'x': 1.5, 'y': 2.0, 'is_correct': true},
        ),
      ]);

      final events = await db.eventsForSession('s1');
      expect(events.single.payloadJson, contains('"is_correct":true'));
    });
  });

  group('PendingUploads', () {
    test('enqueue, list oldest-first, mark attempts, remove', () async {
      await db.enqueueUpload('s1', '{"a":1}');
      await db.enqueueUpload('s2', '{"b":2}');

      var pending = await db.pendingUploadsOldestFirst();
      expect(pending.map((u) => u.sessionId), ['s1', 's2']);
      expect(pending.first.attempts, 0);

      await db.markUploadAttempt('s1');
      pending = await db.pendingUploadsOldestFirst();
      expect(pending.first.attempts, 1);
      expect(pending.first.lastAttemptAt, isNotNull);

      await db.removeUpload('s1');
      pending = await db.pendingUploadsOldestFirst();
      expect(pending.map((u) => u.sessionId), ['s2']);
    });

    test('re-enqueueing a session replaces its payload', () async {
      await db.enqueueUpload('s1', '{"v":1}');
      await db.enqueueUpload('s1', '{"v":2}');
      final pending = await db.pendingUploadsOldestFirst();
      expect(pending, hasLength(1));
      expect(pending.single.payloadJson, '{"v":2}');
    });
  });
}
