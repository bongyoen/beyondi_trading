import '../../../../entities/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../entities/user_credentials.dart';

/// Pure orchestration use case: converts credentials into a [User].
///
/// Depends on [AuthRepository] for the actual authentication, but the
/// use case itself is predictable — same credentials + same repository
/// yields the same result (Atomic Predictability).
class LoginUseCase {
  /// Creates a [LoginUseCase] backed by the given [authRepository].
  const LoginUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  /// Authenticates the user with the given [credentials].
  ///
  /// Returns a [User] on success. Throws on failure (Fail Fast).
  Future<User> call(UserCredentials credentials) {
    // Early Exit: credentials are already parsed & trusted at this point
    return _authRepository.login(credentials);
  }
}
