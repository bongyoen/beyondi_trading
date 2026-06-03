import 'package:equatable/equatable.dart';

sealed class KisAuthEvent extends Equatable {
  const KisAuthEvent();
  @override
  List<Object?> get props => [];
}

class KisConnectRequested extends KisAuthEvent {
  final String userId;
  final String? mockKey, mockSecret, mockAccountNo, mockProductCode;
  final String? realKey, realSecret, realAccountNo, realProductCode;

  const KisConnectRequested({
    required this.userId,
    this.mockKey,
    this.mockSecret,
    this.mockAccountNo,
    this.mockProductCode,
    this.realKey,
    this.realSecret,
    this.realAccountNo,
    this.realProductCode,
  });

  @override
  List<Object?> get props => [userId, mockKey, realKey];
}

class KisStatusRequested extends KisAuthEvent {
  final String userId;
  const KisStatusRequested({required this.userId});
  @override
  List<Object?> get props => [userId];
}

class KisDisconnectRequested extends KisAuthEvent {
  final String userId;
  const KisDisconnectRequested({required this.userId});
  @override
  List<Object?> get props => [userId];
}

class KisToggleEnv extends KisAuthEvent {
  final bool useMock;
  const KisToggleEnv(this.useMock);
  @override
  List<Object?> get props => [useMock];
}
