import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/errors/failures.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../data/auth_repository_impl.dart';
import '../data/feature_flags_cache.dart';
import '../data/platform_gate_repository_impl.dart';
import '../domain/auth_repository.dart';
import '../domain/pin_service.dart';
import '../domain/startup_gate.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Whether the Supabase SDK has a persisted session on disk. The SDK restores
/// and (when online) silently refreshes it during `Supabase.initialize`, so a
/// non-null `currentSession` means "already signed in". Overridable in tests.
final hasPersistedSessionProvider = Provider<bool Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () => client.auth.currentSession != null;
});

final featureFlagsCacheProvider =
    Provider<FeatureFlagsCache>((_) => FeatureFlagsCache());

/// Outcome of restoring a session at app startup.
enum RestoreResult { authenticated, unauthenticated, versionBlocked }

final platformGateRepositoryProvider = Provider<PlatformGateRepository>((ref) {
  return SupabasePlatformGateRepository(ref.watch(supabaseClientProvider));
});

final pinServiceProvider = Provider<PinService>((ref) => PinService());

/// Set once at startup from PackageInfo; overridable in tests.
final appVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('appVersionProvider must be overridden at startup');
});

/// Populated after a successful login; roster/session screens read flags here.
class StartupStateNotifier extends Notifier<StartupState?> {
  @override
  StartupState? build() => null;

  void set(StartupState value) => state = value;
}

final startupStateProvider =
    NotifierProvider<StartupStateNotifier, StartupState?>(StartupStateNotifier.new);

sealed class AuthUiState {
  const AuthUiState();
}

class AuthIdle extends AuthUiState {
  const AuthIdle();
}

class AuthLoading extends AuthUiState {
  const AuthLoading();
}

class AuthError extends AuthUiState {
  final String message;
  const AuthError(this.message);
}

/// Login succeeded and the version gate passed. [needsPinSetup] tells the UI
/// whether to show the PIN dialog before entering the roster.
class AuthSuccess extends AuthUiState {
  final bool needsPinSetup;
  const AuthSuccess({required this.needsPinSetup});
}

class AuthController extends Notifier<AuthUiState> {
  @override
  AuthUiState build() => const AuthIdle();

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      await ref.read(authRepositoryProvider).signIn(email: email, password: password);

      final gate = StartupGate(
        repository: ref.read(platformGateRepositoryProvider),
        appVersion: ref.read(appVersionProvider),
      );
      final startup = await gate.check();
      ref.read(startupStateProvider.notifier).set(startup);
      await ref.read(featureFlagsCacheProvider).save(startup.featureFlags);

      final needsPin = !await ref.read(pinServiceProvider).hasPin();
      state = AuthSuccess(needsPinSetup: needsPin);
    } on VersionBlockedFailure catch (f) {
      // Outdated clients must not proceed even though credentials were valid.
      await ref.read(authRepositoryProvider).signOut();
      state = AuthError(f.message);
    } on Failure catch (f) {
      state = AuthError(f.message);
    } catch (_) {
      state = const AuthError('Something went wrong. Please try again.');
    }
  }

  /// Restores a persisted session at app startup so teachers stay signed in
  /// across restarts. Only returns to login when there is genuinely no session,
  /// the refresh token is invalid/revoked, or the client is version-blocked.
  Future<RestoreResult> restore() async {
    if (!ref.read(hasPersistedSessionProvider)()) {
      return RestoreResult.unauthenticated;
    }
    final gate = StartupGate(
      repository: ref.read(platformGateRepositoryProvider),
      appVersion: ref.read(appVersionProvider),
    );
    try {
      final startup = await gate.check(); // refreshes the token if expired
      ref.read(startupStateProvider.notifier).set(startup);
      await ref.read(featureFlagsCacheProvider).save(startup.featureFlags);
      return RestoreResult.authenticated;
    } on VersionBlockedFailure catch (f) {
      // Outdated client: sign out and surface the message on the login screen.
      await ref.read(authRepositoryProvider).signOut();
      state = AuthError(f.message);
      return RestoreResult.versionBlocked;
    } on AuthException {
      // Refresh token invalid or account revoked — a real re-auth is required.
      await ref.read(authRepositoryProvider).signOut();
      return RestoreResult.unauthenticated;
    } catch (_) {
      // Offline / transient: reopen into the app with last-known flags rather
      // than forcing login. Version + flags re-check on the next online launch.
      final cached = await ref.read(featureFlagsCacheProvider).load();
      ref.read(startupStateProvider.notifier).set(
            StartupState(featureFlags: cached),
          );
      return RestoreResult.authenticated;
    }
  }

  static Future<String> currentAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthUiState>(AuthController.new);
