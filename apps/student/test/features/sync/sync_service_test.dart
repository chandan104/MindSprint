import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/data/local/app_database.dart';
import 'package:mindsprint_student/features/sync/application/sync_service.dart';

class _FakeGateway implements UploadGateway {
  bool failNext = false;
  final sent = <({Map<String, Object?> session, List<Map<String, Object?>> events})>[];

  @override
  Future<void> send(
      Map<String, Object?> session, List<Map<String, Object?>> events) async {
    if (failNext) throw Exception('network down');
    sent.add((session: session, events: events));
  }
}

SessionUploadMeta _meta(String sessionId) => SessionUploadMeta(
      sessionId: sessionId,
      studentId: 'st1',
      classId: 'c1',
      schoolId: 'sc1',
      moduleKey: 'memory_recall',
      levelVersionId: 'lv1',
      startedAt: DateTime.utc(2026, 7, 20, 9),
      completedAt: DateTime.utc(2026, 7, 20, 9, 1),
      wasInterrupted: false,
      provisionalMetrics: const {'accuracy': 0.75},
      deviceMeta: const {'platform': 'test'},
    );

void main() {
  late AppDatabase db;
  late _FakeGateway gateway;
  late SyncService sync;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeGateway();
    sync = SyncService(db: db, gateway: gateway);

    await db.insertEvents([
      const LocalEventsCompanion(
        sessionId: Value('s1'),
        seq: Value(1),
        eventType: Value('session_started'),
        tMs: Value(0),
        payloadJson: Value('{}'),
      ),
      const LocalEventsCompanion(
        sessionId: Value('s1'),
        seq: Value(2),
        eventType: Value('tap_registered'),
        tMs: Value(1500),
        payloadJson:
            Value('{"target_kind":"choice","is_correct":true,"x":1,"y":2}'),
      ),
    ]);
  });

  tearDown(() => db.close());

  test('successful upload sends ordered events and prunes local copies',
      () async {
    final ok = await sync.uploadSession(_meta('s1'));

    expect(ok, isTrue);
    expect(gateway.sent, hasLength(1));
    final payload = gateway.sent.single;
    expect(payload.session['id'], 's1');
    expect(payload.session['student_id'], 'st1');
    expect(payload.session['provisional_metrics'], {'accuracy': 0.75});
    expect(payload.events.map((e) => e['seq']), [1, 2]);
    expect((payload.events[1]['payload'] as Map)['is_correct'], true);

    expect(await db.eventsForSession('s1'), isEmpty);
    expect(await sync.pendingCount(), 0);
  });

  test('failed upload parks the full payload in the retry queue', () async {
    gateway.failNext = true;
    final ok = await sync.uploadSession(_meta('s1'));

    expect(ok, isFalse);
    expect(await sync.pendingCount(), 1);
    // The queue row is now the durable copy; raw event rows are pruned.
    expect(await db.eventsForSession('s1'), isEmpty);
  });

  test('retryPending drains the queue and removes acknowledged rows',
      () async {
    gateway.failNext = true;
    await sync.uploadSession(_meta('s1'));
    expect(await sync.pendingCount(), 1);

    gateway.failNext = false;
    final remaining = await sync.retryPending();

    expect(remaining, 0);
    expect(await sync.pendingCount(), 0);
    expect(gateway.sent, hasLength(1));
    expect(gateway.sent.single.session['id'], 's1');
    expect(gateway.sent.single.events, hasLength(2));
  });

  test('retryPending stops at first failure and records the attempt',
      () async {
    gateway.failNext = true;
    await sync.uploadSession(_meta('s1'));

    gateway.failNext = true;
    final remaining = await sync.retryPending();

    expect(remaining, 1);
    final row = (await db.pendingUploadsOldestFirst()).single;
    expect(row.attempts, 1);
    expect(row.lastAttemptAt, isNotNull);
  });
}
