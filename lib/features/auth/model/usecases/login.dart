import 'package:beyondi_trading/entities/user/model/user.dart';
import 'package:beyondi_trading/features/auth/api/auth_repository.dart';
import 'package:beyondi_trading/entities/user_credentials/model/user_credentials.dart';

class LoginUseCase {
  const LoginUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<User> call(UserCredentials credentials) {
    return _authRepository.login(credentials);
  }
}
