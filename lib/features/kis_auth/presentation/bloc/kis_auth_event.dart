import 'package:equatable/equatable.dart';

/// [KisAuthBloc]에 전달되는 이벤트.
sealed class KisAuthEvent extends Equatable {
  const KisAuthEvent();
  @override
  List<Object?> get props => [];
}

/// 키/시크릿으로 KIS 연결 시도.
final class KisConnectRequested extends KisAuthEvent {
  const KisConnectRequested({
    required this.appKey,
    required this.appSecret,
    required this.userId,
    this.isPaper = true,
  });

  final String appKey;
  final String appSecret;
  final String userId;
  final bool isPaper;

  @override
  List<Object?> get props => [appKey, appSecret, userId, isPaper];
}

/// 저장된 KIS 연결 상태 조회.
final class KisStatusRequested extends KisAuthEvent {
  const KisStatusRequested({required this.userId});
  final String userId;
  @override
  List<Object?> get props => [userId];
}

/// KIS 연결 해제.
final class KisDisconnectRequested extends KisAuthEvent {
  const KisDisconnectRequested({required this.userId});
  final String userId;
  @override
  List<Object?> get props => [userId];
}
