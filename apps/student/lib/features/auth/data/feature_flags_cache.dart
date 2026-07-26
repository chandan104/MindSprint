import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Last-known feature flags, persisted so a session can be restored offline
/// with a usable roster instead of forcing the teacher to reconnect first.
/// Flags are not secret; secure storage is simply the KV store already in use.
class FeatureFlagsCache {
  static const _key = 'cached_feature_flags';
  final FlutterSecureStorage _storage;

  FeatureFlagsCache([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save(Map<String, bool> flags) =>
      _storage.write(key: _key, value: jsonEncode(flags));

  Future<Map<String, bool>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in map.entries) e.key: e.value == true};
    } catch (_) {
      return const {};
    }
  }
}
