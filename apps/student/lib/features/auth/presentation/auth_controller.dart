import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

import '../../../core/errors/failures.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../data/auth_repository_impl.dart';
import '../data/platform_gate_repository_impl.dart';
import '../domain/auth_repository.dart';
import '../domain/pin_service.dart';
import '../domain/startup_gate.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final platformGateRepositoryProvider = Provider<PlatformGateRepository>((ref) {
  return SupabasePlatformGateRepository(ref.watch(supabaseClientProvider));
});

final pinServiceProvider = Provider<PinService>((ref) => PinService());

/// Set once at startup from PackageInfo; overridable in tests.
final appVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('appVersionProvider must be overridden at startup');
});

/// Populated after a successful login; roster/session screens read flags here.
final startupStateProvider = StateProvider<StartupState?>((ref) => null);

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
      ref.read(startupStateProvider.notifier).state = startup;

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

  static Future<String> currentAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthUiState>(AuthController.new);
