import '../../../../entities/user.dart';
import '../../../../shared/api/api_client.dart';
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

  /// Registers a new user with the given [credentials] and profile info.
  ///
  /// Returns the newly created [User] on success. Throws [AuthException]
  /// on failure (e.g., duplicate ID or invalid data).
  Future<User> register({
    required UserCredentials credentials,
    required String name,
    required String email,
  });
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

    // Early Exit: guard against empty input (belt-and-suspenders with
    // UserCredentials assertion)
    if (credentials.id.isEmpty || credentials.password.isEmpty) {
      throw AuthException('아이디와 비밀번호를 입력해주세요.');
    }

    // Demo: any non-empty credentials succeed
    return User(
      id: credentials.id,
      name: credentials.id,
      email: '${credentials.id}@beyondi.com',
    );
  }

  @override
  Future<User> register({
    required UserCredentials credentials,
    required String name,
    required String email,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));

    // Early Exit: guard against empty input
    if (credentials.id.isEmpty || credentials.password.isEmpty) {
      throw AuthException('아이디와 비밀번호를 입력해주세요.');
    }

    // Demo: any non-empty input succeeds
    return User(
      id: credentials.id,
      name: name,
      email: email,
    );
  }
}

/// Cloudflare Workers API authentication implementation.
///
/// Calls the authentication endpoints on the CF Workers API for real
/// login and registration. Parses JSON responses at the boundary
/// (Parse Don't Validate) into trusted [User] objects.
class WorkersAuthRepository implements AuthRepository {
  /// Creates a [WorkersAuthRepository] backed by the given [apiClient].
  const WorkersAuthRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<User> login(UserCredentials credentials) async {
    // Early Exit: credentials are already parsed by UserCredentials
    // at the boundary — no additional validation needed here.

    final Map<String, dynamic> response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': credentials.id,
        'password': credentials.password,
      },
    );

    // Parse the user object from the response at the boundary.
    return _parseUserFromResponse(response);
  }

  @override
  Future<User> register({
    required UserCredentials credentials,
    required String name,
    required String email,
  }) async {
    final Map<String, dynamic> response = await _apiClient.post(
      '/auth/register',
      body: {
        'email': credentials.id,
        'password': credentials.password,
        'name': name,
      },
    );

    // Parse the user object from the response at the boundary.
    return _parseUserFromResponse(response);
  }

  /// Extracts a [User] from a JSON API response.
  ///
  /// Supports two common response shapes:
  ///   1. `{ "user": { "id": "...", "name": "...", "email": "..." } }` (nested)
  ///   2. `{ "id": "...", "name": "...", "email": "..." }` (flat)
  ///
  /// Throws [AuthException] if the response is malformed (Fail Fast).
  User _parseUserFromResponse(Map<String, dynamic> response) {
    // Attempt to extract the nested user object if present.
    final Map<String, dynamic> userData =
        response['user'] is Map<String, dynamic>
            ? response['user'] as Map<String, dynamic>
            : response;

    final String? id = userData['id'] as String?;
    final String? name = userData['name'] as String?;
    final String? email = userData['email'] as String?;

    // Fail Loud: if any required field is missing, halt immediately.
    if (id == null || name == null || email == null) {
      throw AuthException(
        'Invalid response from authentication server: '
        'missing required user fields.',
      );
    }

    return User(id: id, name: name, email: email);
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
