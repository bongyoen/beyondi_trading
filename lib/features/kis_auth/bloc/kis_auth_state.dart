import 'package:equatable/equatable.dart';

import 'package:beyondi_trading/entities/kis_connection/model/kis_connection.dart';

sealed class KisAuthState extends Equatable {
  const KisAuthState();
  @override
  List<Object?> get props => [];
}

class KisAuthInitial extends KisAuthState {
  const KisAuthInitial();
}

class KisAuthLoading extends KisAuthState {
  const KisAuthLoading();
}

class KisAuthConnected extends KisAuthState {
  final KisConnection connection;
  const KisAuthConnected({required this.connection});
  @override
  List<Object?> get props => [connection];
}

class KisAuthDisconnected extends KisAuthState {
  const KisAuthDisconnected();
}

class KisAuthFailure extends KisAuthState {
  final String message;
  const KisAuthFailure({required this.message});
  @override
  List<Object?> get props => [message];
}
