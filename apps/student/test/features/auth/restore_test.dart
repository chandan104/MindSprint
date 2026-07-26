import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/features/auth/data/feature_flags_cache.dart';
import 'package:mindsprint_student/features/auth/domain/auth_repository.dart';
import 'package:mindsprint_student/features/auth/domain/startup_gate.dart';
import 'package:mindsprint_student/features/auth/presentation/auth_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockGateRepository extends Mock implements PlatformGateRepository {}

class _FakeFlagsCache extends FeatureFlagsCache {
  Map<String, bool> saved = const {};
  @override
  Future<void> save(Map<String, bool> flags) async => saved = flags;
  @override
  Future<Map<String, bool>> load() async => saved;
}

class _FakeAuthRepo implements AuthRepository {
  bool signedOut = false;
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signOut() async => signedOut = true;
  @override
  bool get isSignedIn => !signedOut;
}

ProviderContainer _container({
  required bool hasSession,
  required _MockGateRepository gate,
  required _FakeFlagsCache cache,
  required _FakeAuthRepo auth,
}) {
  return ProviderContainer(overrides: [
    appVersionProvider.overrideWithValue('1.0.0'),
    hasPersistedSessionProvider.overrideWithValue(() => hasSession),
    platformGateRepositoryProvider.overrideWithValue(gate),
    featureFlagsCacheProvider.overrideWithValue(cache),
    authRepositoryProvider.overrideWithValue(auth),
  ]);
}

void main() {
  late _MockGateRepository gate;
  late _FakeFlagsCache cache;
  late _FakeAuthRepo auth;

  setUp(() {
    gate = _MockGateRepository();
    cache = _FakeFlagsCache();
    auth = _FakeAuthRepo();
  });

  test('no persisted session → unauthenticated (must log in)', () async {
    final c = _container(hasSession: false, gate: gate, cache: cache, auth: auth);
    addTearDown(c.dispose);
    final result = await c.read(authControllerProvider.notifier).restore();
    expect(result, RestoreResult.unauthenticated);
  });

  test('valid session online → authenticated, flags loaded & cached', () async {
    when(() => gate.minimumSupportedVersion()).thenAnswer((_) async => '0.1.0');
    when(() => gate.featureFlags())
        .thenAnswer((_) async => {'memory_module': true});
    final c = _container(hasSession: true, gate: gate, cache: cache, auth: auth);
    addTearDown(c.dispose);

    final result = await c.read(authControllerProvider.notifier).restore();

    expect(result, RestoreResult.authenticated);
    expect(c.read(startupStateProvider)!.flag('memory_module'), isTrue);
    expect(cache.saved['memory_module'], isTrue, reason: 'flags cached');
  });

  test('offline restore falls back to cached flags, stays signed in', () async {
    cache.saved = const {'memory_module': true};
    when(() => gate.minimumSupportedVersion())
        .thenThrow(Exception('network down'));
    final c = _container(hasSession: true, gate: gate, cache: cache, auth: auth);
    addTearDown(c.dispose);

    final result = await c.read(authControllerProvider.notifier).restore();

    expect(result, RestoreResult.authenticated,
        reason: 'offline must not force login when a session exists');
    expect(c.read(startupStateProvider)!.flag('memory_module'), isTrue);
    expect(auth.signedOut, isFalse);
  });

  test('version-blocked client signs out and returns to login', () async {
    when(() => gate.minimumSupportedVersion()).thenAnswer((_) async => '9.9.9');
    when(() => gate.featureFlags()).thenAnswer((_) async => const {});
    final c = _container(hasSession: true, gate: gate, cache: cache, auth: auth);
    addTearDown(c.dispose);

    final result = await c.read(authControllerProvider.notifier).restore();

    expect(result, RestoreResult.versionBlocked);
    expect(auth.signedOut, isTrue);
  });
}
