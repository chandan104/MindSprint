import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/app_database.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../assessments/engine/session_recorder.dart';

/// Network boundary for uploads, kept behind an interface so the sync logic
/// is fully testable without Supabase.
abstract interface class UploadGateway {
  /// Throws on any failure; success means the server has the session.
  Future<void> send(Map<String, Object?> session, List<Map<String, Object?>> events);
}

class SupabaseUploadGateway implements UploadGateway {
  final SupabaseClient _client;
  SupabaseUploadGateway(this._client);

  @override
  Future<void> send(
      Map<String, Object?> session, List<Map<String, Object?>> events) {
    return _client.rpc<void>('upload_session', params: {
      'p_session': session,
      'p_events': events,
    });
  }
}

/// Everything the upload payload needs beyond the recorded events.
class SessionUploadMeta {
  final String sessionId;
  final String studentId;
  final String classId;
  final String schoolId;
  final String moduleKey;
  final String levelVersionId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool wasInterrupted;
  final Map<String, Object?>? provisionalMetrics;
  final Map<String, Object?> deviceMeta;
  final int eventSchemaVersion;

  const SessionUploadMeta({
    required this.sessionId,
    required this.studentId,
    required this.classId,
    required this.schoolId,
    required this.moduleKey,
    required this.levelVersionId,
    required this.startedAt,
    required this.completedAt,
    required this.wasInterrupted,
    required this.provisionalMetrics,
    required this.deviceMeta,
    this.eventSchemaVersion = 1,
  });

  Map<String, Object?> toSessionJson() => {
        'id': sessionId,
        'student_id': studentId,
        'class_id': classId,
        'school_id': schoolId,
        'module_key': moduleKey,
        'level_version_id': levelVersionId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'was_interrupted': wasInterrupted,
        'provisional_metrics': provisionalMetrics,
        'device_meta': deviceMeta,
        'event_schema_version': eventSchemaVersion,
      };
}

/// Upload orchestration (spec section 9): assemble the complete payload from
/// the local event store, try one atomic RPC, and on any failure park the
/// whole payload in the retry queue. Local event rows are pruned once the
/// payload exists elsewhere (server or queue) - the queue row IS the durable
/// copy.
class SyncService {
  final AppDatabase db;
  final UploadGateway gateway;

  SyncService({required this.db, required this.gateway});

  /// Returns true when the server acknowledged; false when queued for retry.
  Future<bool> uploadSession(SessionUploadMeta meta) async {
    final rows = await db.eventsForSession(meta.sessionId);
    final events = <Map<String, Object?>>[
      for (final row in rows)
        {
          'seq': row.seq,
          'event_type': row.eventType,
          't_ms': row.tMs,
          'payload': SessionRecorder.decodePayload(row.payloadJson),
        },
    ];
    final session = meta.toSessionJson();

    try {
      await gateway.send(session, events);
      await db.deleteEventsForSession(meta.sessionId);
      await db.removeUpload(meta.sessionId);
      return true;
    } catch (_) {
      await db.enqueueUpload(
        meta.sessionId,
        jsonEncode({'session': session, 'events': events}),
      );
      await db.deleteEventsForSession(meta.sessionId);
      return false;
    }
  }

  /// Drains the retry queue oldest-first. Stops at the first failure (if one
  /// upload fails, later ones almost certainly will too). Returns how many
  /// remain queued.
  Future<int> retryPending() async {
    final pending = await db.pendingUploadsOldestFirst();
    var remaining = pending.length;
    for (final row in pending) {
      try {
        final decoded = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        final session = Map<String, Object?>.from(decoded['session'] as Map);
        final events = [
          for (final e in decoded['events'] as List)
            Map<String, Object?>.from(e as Map),
        ];
        await gateway.send(session, events);
        await db.removeUpload(row.sessionId);
        remaining--;
      } catch (_) {
        await db.markUploadAttempt(row.sessionId);
        break;
      }
    }
    return remaining;
  }

  Future<int> pendingCount() async =>
      (await db.pendingUploadsOldestFirst()).length;
}

final uploadGatewayProvider = Provider<UploadGateway>((ref) {
  return SupabaseUploadGateway(ref.watch(supabaseClientProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(appDatabaseProvider),
    gateway: ref.watch(uploadGatewayProvider),
  );
});

/// Watched by the class-list badge; invalidate after any upload/retry.
final pendingUploadCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(syncServiceProvider).pendingCount();
});
