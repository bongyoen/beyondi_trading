import 'package:equatable/equatable.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({
    required this.id,
    required this.password,
  });

  final String id;
  final String password;

  @override
  List<Object?> get props => [id, password];
}

final class LoginReset extends LoginEvent {
  const LoginReset();
}
