import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../domain/startup_gate.dart';

class SupabasePlatformGateRepository implements PlatformGateRepository {
  final SupabaseClient _client;
  SupabasePlatformGateRepository(this._client);

  @override
  Future<String?> minimumSupportedVersion() async {
    try {
      final rows = await _client
          .from('app_versions')
          .select('minimum_supported_version')
          .order('released_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['minimum_supported_version'] as String?;
    } on SocketException {
      throw const NetworkFailure();
    } on PostgrestException catch (e) {
      throw UnknownFailure('Could not check app version: ${e.message}');
    }
  }

  @override
  Future<Map<String, bool>> featureFlags() async {
    try {
      final rows = await _client.from('feature_flags').select('key, enabled');
      return {
        for (final row in rows) row['key'] as String: row['enabled'] as bool,
      };
    } on SocketException {
      throw const NetworkFailure();
    } on PostgrestException catch (e) {
      throw UnknownFailure('Could not load feature flags: ${e.message}');
    }
  }
}
