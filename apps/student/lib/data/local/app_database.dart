import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// On-device event buffer. Rows live here from the moment gameplay records
/// them until the server acknowledges the session upload; the local copy of
/// recent sessions is retained briefly for debugging, then pruned.
class LocalEvents extends Table {
  TextColumn get sessionId => text()();
  IntColumn get seq => integer()();
  TextColumn get eventType => text()();
  IntColumn get tMs => integer()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {sessionId, seq};
}

/// Retry queue for failed session uploads. One row per session; the payload
/// is the complete, ready-to-send upload body so retries never depend on
/// re-reading gameplay state.
class PendingUploads extends Table {
  TextColumn get sessionId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {sessionId};
}

@DriftDatabase(tables: [LocalEvents, PendingUploads])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'mindsprint_student'));

  /// In-memory or custom executor for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<void> insertEvents(List<LocalEventsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(localEvents, rows));
  }

  Future<List<LocalEvent>> eventsForSession(String sessionId) {
    return (select(localEvents)
          ..where((e) => e.sessionId.equals(sessionId))
          ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
        .get();
  }

  Future<void> deleteEventsForSession(String sessionId) {
    return (delete(localEvents)..where((e) => e.sessionId.equals(sessionId))).go();
  }

  Future<void> enqueueUpload(String sessionId, String payloadJson) {
    return into(pendingUploads).insertOnConflictUpdate(
      PendingUploadsCompanion.insert(sessionId: sessionId, payloadJson: payloadJson),
    );
  }

  Future<List<PendingUpload>> pendingUploadsOldestFirst() {
    return (select(pendingUploads)
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
        .get();
  }

  Future<void> markUploadAttempt(String sessionId) async {
    final row = await (select(pendingUploads)
          ..where((u) => u.sessionId.equals(sessionId)))
        .getSingleOrNull();
    if (row == null) return;
    await (update(pendingUploads)..where((u) => u.sessionId.equals(sessionId))).write(
      PendingUploadsCompanion(
        attempts: Value(row.attempts + 1),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> removeUpload(String sessionId) {
    return (delete(pendingUploads)..where((u) => u.sessionId.equals(sessionId))).go();
  }
}
