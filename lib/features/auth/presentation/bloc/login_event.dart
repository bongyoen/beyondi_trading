import 'package:equatable/equatable.dart';

/// Events dispatched to [LoginBloc].
///
/// Using sealed class ensures exhaustive handling and prevents
/// illegal states (Parse Don't Validate).
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Event submitted when the user presses the login button.
///
/// Contains the parsed [id] and [password] from the form, which
/// have already been validated at the UI boundary.
final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({
    required this.id,
    required this.password,
  });

  /// The user's login ID.
  final String id;

  /// The user's password.
  final String password;

  @override
  List<Object?> get props => [id, password];
}

/// Event dispatched to reset the auth state to initial (e.g., after
/// a failure, when the user starts editing fields).
final class LoginReset extends LoginEvent {
  const LoginReset();
}
