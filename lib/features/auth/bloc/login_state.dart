import 'package:equatable/equatable.dart';

import 'package:beyondi_trading/entities/user/model/user.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginLoading extends LoginState {
  const LoginLoading();
}

final class LoginSuccess extends LoginState {
  const LoginSuccess({required this.user});

  final User user;

  @override
  List<Object?> get props => [user];
}

final class LoginFailure extends LoginState {
  const LoginFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
