import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/user_credentials.dart';
import '../../domain/usecases/login.dart';
import 'login_event.dart';
import 'login_state.dart';

/// Business logic component for user authentication.
///
/// Orchestrates the login flow: receives [LoginEvent]s, validates
/// through the [LoginUseCase], and emits [LoginState]s.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required AuthRepository authRepository})
    : _loginUseCase = LoginUseCase(authRepository: authRepository),
      super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginReset>(_onLoginReset);
  }

  final LoginUseCase _loginUseCase;

  /// Handles the [LoginSubmitted] event.
  ///
  /// Parses credentials, emits loading, attempts auth, and emits
  /// either success or failure (Fail Fast, Fail Loud).
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // Early Exit: guard against empty input (belt-and-suspenders with
    // UserCredentials assertion)
    if (event.id.isEmpty || event.password.isEmpty) {
      emit(const LoginFailure(message: '아이디와 비밀번호를 입력해주세요.'));
      return;
    }

    emit(const LoginLoading());

    try {
      // Parse at the boundary: create trusted credentials object
      final UserCredentials credentials = UserCredentials(
        id: event.id,
        password: event.password,
      );

      final user = await _loginUseCase(credentials);

      emit(LoginSuccess(user: user));
    } on AuthException catch (e) {
      emit(LoginFailure(message: e.message));
    } catch (e) {
      // Fail Loud: any unexpected error is surfaced immediately
      emit(LoginFailure(message: '예기치 않은 오류가 발생했습니다. 다시 시도해주세요.'));
    }
  }

  /// Handles the [LoginReset] event — returns to initial state.
  void _onLoginReset(
    LoginReset event,
    Emitter<LoginState> emit,
  ) {
    emit(const LoginInitial());
  }
}
