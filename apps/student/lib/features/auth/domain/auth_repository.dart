import '../../../core/errors/failures.dart';

abstract interface class AuthRepository {
  /// Signs the teacher in. Throws a [Failure] subtype on error.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  bool get isSignedIn;
}
