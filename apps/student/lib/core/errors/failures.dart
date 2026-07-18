/// Domain-level failures surfaced to controllers/UI. Repository
/// implementations translate exceptions (network, auth, storage) into these
/// so presentation code never depends on infrastructure exception types.
sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No connection. Check the network and try again.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sign-in failed. Check the email and password.']);
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Could not save data on this device.']);
}

class VersionBlockedFailure extends Failure {
  const VersionBlockedFailure(
      [super.message = 'This app version is no longer supported. Please update.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong. Please try again.']);
}
