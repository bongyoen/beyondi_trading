import 'package:beyondi_trading/entities/user/model/user.dart';
import 'package:beyondi_trading/shared/api/api_client.dart';
import 'package:beyondi_trading/entities/user_credentials/model/user_credentials.dart';

abstract class AuthRepository {
  Future<User> login(UserCredentials credentials);

  Future<User> register({
    required UserCredentials credentials,
    required String name,
    required String email,
  });
}

class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  Future<User> login(UserCredentials credentials) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (credentials.id.isEmpty || credentials.password.isEmpty) {
      throw AuthException('아이디와 비밀번호를 입력해주세요.');
    }

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
    await Future.delayed(const Duration(milliseconds: 800));

    if (credentials.id.isEmpty || credentials.password.isEmpty) {
      throw AuthException('아이디와 비밀번호를 입력해주세요.');
    }

    return User(
      id: credentials.id,
      name: name,
      email: email,
    );
  }
}

class WorkersAuthRepository implements AuthRepository {
  const WorkersAuthRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<User> login(UserCredentials credentials) async {
    final Map<String, dynamic> response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': credentials.id,
        'password': credentials.password,
      },
    );

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

    return _parseUserFromResponse(response);
  }

  User _parseUserFromResponse(Map<String, dynamic> response) {
    final Map<String, dynamic> userData =
        response['user'] is Map<String, dynamic>
            ? response['user'] as Map<String, dynamic>
            : response;

    final String? id = userData['id'] as String?;
    final String? name = userData['name'] as String?;
    final String? email = userData['email'] as String?;

    if (id == null || name == null || email == null) {
      throw AuthException(
        'Invalid response from authentication server: '
        'missing required user fields.',
      );
    }

    return User(id: id, name: name, email: email);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
