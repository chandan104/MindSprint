import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/timing/timing_service.dart';
import '../../../data/local/app_database.dart';

/// Persistence boundary for the recorder, so gameplay code and tests never
/// touch Drift directly.
abstract interface class EventStore {
  Future<void> saveEvents(List<RecordedEvent> events);
}

class DriftEventStore implements EventStore {
  final AppDatabase _db;
  DriftEventStore(this._db);

  @override
  Future<void> saveEvents(List<RecordedEvent> events) {
    return _db.insertEvents([
      for (final e in events)
        LocalEventsCompanion(
          sessionId: Value(e.sessionId),
          seq: Value(e.seq),
          eventType: Value(e.eventType),
          tMs: Value(e.tMs),
          payloadJson: Value(jsonEncode(e.payload)),
        ),
    ]);
  }
}

class RecordedEvent {
  final String sessionId;
  final int seq;
  final String eventType;
  final int tMs;
  final Map<String, Object?> payload;

  const RecordedEvent({
    required this.sessionId,
    required this.seq,
    required this.eventType,
    required this.tMs,
    required this.payload,
  });
}

/// Records gameplay events for one session.
///
/// Contract (spec §8/§9): seq is strictly increasing from 1; t_ms comes from
/// the monotonic [TimingService]; events buffer in memory and flush to the
/// [EventStore] every [flushInterval] and on [flush]/[dispose] — gameplay
/// never waits on disk. One recorder per session; never reuse.
class SessionRecorder {
  final String sessionId;
  final TimingService _timing;
  final EventStore _store;
  final Duration flushInterval;

  final List<RecordedEvent> _buffer = [];
  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  SessionRecorder({
    required this.sessionId,
    required TimingService timing,
    required EventStore store,
    this.flushInterval = const Duration(milliseconds: 500),
  })  : _timing = timing,
        _store = store {
    _timer = Timer.periodic(flushInterval, (_) => flush());
  }

  int get nextSeq => _seq + 1;

  /// Records an event with the current monotonic timestamp. Synchronous and
  /// allocation-light: gameplay calls this from input handlers.
  RecordedEvent record(String eventType, [Map<String, Object?> payload = const {}]) {
    if (_disposed) {
      throw StateError('SessionRecorder used after dispose');
    }
    final event = RecordedEvent(
      sessionId: sessionId,
      seq: ++_seq,
      eventType: eventType,
      tMs: _timing.nowMs,
      payload: payload,
    );
    _buffer.add(event);
    return event;
  }

  /// Records and immediately persists — for lifecycle events
  /// (session_started/completed/aborted, pause, backgrounding) where losing
  /// the event to a crash would corrupt the session record.
  Future<RecordedEvent> recordAndFlush(String eventType,
      [Map<String, Object?> payload = const {}]) async {
    final event = record(eventType, payload);
    await flush();
    return event;
  }

  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<RecordedEvent>.unmodifiable(_buffer);
    _buffer.clear();
    await _store.saveEvents(batch);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    if (_buffer.isNotEmpty) {
      final batch = List<RecordedEvent>.unmodifiable(_buffer);
      _buffer.clear();
      await _store.saveEvents(batch);
    }
  }
}
