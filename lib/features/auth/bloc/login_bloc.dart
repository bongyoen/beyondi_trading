import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/features/auth/api/auth_repository.dart';
import 'package:beyondi_trading/entities/user_credentials/model/user_credentials.dart';
import 'package:beyondi_trading/features/auth/model/usecases/login.dart';
import 'package:beyondi_trading/features/auth/bloc/login_event.dart';
import 'package:beyondi_trading/features/auth/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required AuthRepository authRepository})
    : _loginUseCase = LoginUseCase(authRepository: authRepository),
      super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginReset>(_onLoginReset);
  }

  final LoginUseCase _loginUseCase;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (event.id.isEmpty || event.password.isEmpty) {
      emit(const LoginFailure(message: '아이디와 비밀번호를 입력해주세요.'));
      return;
    }

    emit(const LoginLoading());

    try {
      final UserCredentials credentials = UserCredentials(
        id: event.id,
        password: event.password,
      );

      final user = await _loginUseCase(credentials);

      emit(LoginSuccess(user: user));
    } on AuthException catch (e) {
      emit(LoginFailure(message: e.message));
    } catch (e) {
      emit(LoginFailure(message: '예기치 않은 오류가 발생했습니다. 다시 시도해주세요.'));
    }
  }

  void _onLoginReset(
    LoginReset event,
    Emitter<LoginState> emit,
  ) {
    emit(const LoginInitial());
  }
}
