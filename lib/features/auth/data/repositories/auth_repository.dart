import '../../../../entities/user.dart';
import '../../domain/entities/user_credentials.dart';

/// Boundary contract for authentication data access.
///
/// The domain layer depends only on this abstraction. Concrete
/// implementations handle the actual auth mechanism (API, demo, etc.).
abstract class AuthRepository {
  /// Authenticates the user with the given [credentials].
  ///
  /// Returns a [User] on success. Throws [AuthException] on failure.
  Future<User> login(UserCredentials credentials);
}

/// Demo authentication that accepts any non-empty credentials.
///
/// Used for testing and development. Simulates a network delay to
/// demonstrate loading states.
class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  Future<User> login(UserCredentials credentials) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));

    // Early Exit: ensure credentials are non-empty (defensive, though
    // UserCredentials already enforces this at parse time)
    if (credentials.id.isEmpty || credentials.password.isEmpty) {
      throw AuthException('ID and password are required.');
    }

    // Demo: any non-empty credentials succeed
    return User(
      id: credentials.id,
      name: credentials.id,
      email: '${credentials.id}@beyondi.com',
    );
  }
}

/// Exception thrown when authentication fails.
class AuthException implements Exception {
  const AuthException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
