import 'package:equatable/equatable.dart';

import '../../domain/entities/kis_connection.dart';

/// KIS 인증 BLoC 상태.
sealed class KisAuthState extends Equatable {
  const KisAuthState();
  @override
  List<Object?> get props => [];
}

/// 초기 상태 — 아직 확인되지 않음.
final class KisAuthInitial extends KisAuthState {
  const KisAuthInitial();
}

/// 연결 진행 중.
final class KisAuthLoading extends KisAuthState {
  const KisAuthLoading();
}

/// KIS API에 연결됨.
final class KisAuthConnected extends KisAuthState {
  const KisAuthConnected({required this.connection});
  final KisConnection connection;

  @override
  List<Object?> get props => [connection];
}

/// KIS 미연결.
final class KisAuthDisconnected extends KisAuthState {
  const KisAuthDisconnected();
}

/// 연결 실패.
final class KisAuthFailure extends KisAuthState {
  const KisAuthFailure({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}
