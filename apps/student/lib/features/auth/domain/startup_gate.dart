import '../../../core/errors/failures.dart';

/// Result of the post-login platform checks: version gate + feature flags.
class StartupState {
  final Map<String, bool> featureFlags;
  const StartupState({required this.featureFlags});

  bool flag(String key) => featureFlags[key] ?? false;
}

abstract interface class PlatformGateRepository {
  /// Latest minimum_supported_version from app_versions, or null when the
  /// table is empty (fresh environments never lock everyone out).
  Future<String?> minimumSupportedVersion();

  Future<Map<String, bool>> featureFlags();
}

/// Compares dotted numeric versions ("0.1.0" style). Missing segments are 0.
/// Returns negative when [a] < [b], 0 when equal, positive when [a] > [b].
int compareVersions(String a, String b) {
  final as = a.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final bs = b.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final len = as.length > bs.length ? as.length : bs.length;
  for (var i = 0; i < len; i++) {
    final av = i < as.length ? as[i] : 0;
    final bv = i < bs.length ? bs[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

/// Runs after every successful login (online-required makes this free):
/// blocks outdated clients, then loads server-side feature flags.
class StartupGate {
  final PlatformGateRepository _repository;
  final String appVersion;

  StartupGate({required PlatformGateRepository repository, required this.appVersion})
      : _repository = repository;

  Future<StartupState> check() async {
    final minimum = await _repository.minimumSupportedVersion();
    if (minimum != null && compareVersions(appVersion, minimum) < 0) {
      throw const VersionBlockedFailure();
    }
    return StartupState(featureFlags: await _repository.featureFlags());
  }
}
