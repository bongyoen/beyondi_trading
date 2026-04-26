import 'package:equatable/equatable.dart';

import '../../../../entities/user.dart';

/// Possible states of the login flow.
///
/// Using sealed class guarantees exhaustive matching in the UI layer,
/// making illegal states unrepresentable.
sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state — no login attempt has been made.
final class LoginInitial extends LoginState {
  const LoginInitial();
}

/// Login is in progress — show a loading indicator.
final class LoginLoading extends LoginState {
  const LoginLoading();
}

/// Login succeeded — contains the authenticated [User].
final class LoginSuccess extends LoginState {
  const LoginSuccess({required this.user});

  /// The authenticated user.
  final User user;

  @override
  List<Object?> get props => [user];
}

/// Login failed — contains a human-readable [message].
final class LoginFailure extends LoginState {
  const LoginFailure({required this.message});

  /// Description of what went wrong.
  final String message;

  @override
  List<Object?> get props => [message];
}
