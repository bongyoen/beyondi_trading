import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/kis_auth_repository.dart';
import 'kis_auth_event.dart';
import 'kis_auth_state.dart';

/// KIS Open API 인증 상태 관리 BLoC.
///
/// Cloudflare Workers API를 통해 KIS 키/시크릿을 저장/조회하고
/// KisStockApi로 직접 토큰 유효성 검증.
class KisAuthBloc extends Bloc<KisAuthEvent, KisAuthState> {
  KisAuthBloc({required KisAuthRepository repository})
      : _repository = repository,
        super(const KisAuthInitial()) {
    on<KisConnectRequested>(_onConnect);
    on<KisStatusRequested>(_onStatus);
    on<KisDisconnectRequested>(_onDisconnect);
  }

  final KisAuthRepository _repository;

  Future<void> _onConnect(
    KisConnectRequested event,
    Emitter<KisAuthState> emit,
  ) async {
    emit(const KisAuthLoading());
    try {
      final connection = await _repository.connect(
        appKey: event.appKey,
        appSecret: event.appSecret,
        userId: event.userId,
        isPaper: event.isPaper,
      );
      emit(KisAuthConnected(connection: connection));
    } catch (e) {
      emit(KisAuthFailure(message: e.toString()));
    }
  }

  Future<void> _onStatus(
    KisStatusRequested event,
    Emitter<KisAuthState> emit,
  ) async {
    emit(const KisAuthLoading());
    try {
      final connection = await _repository.getConnection(event.userId);
      if (connection != null) {
        emit(KisAuthConnected(connection: connection));
      } else {
        emit(const KisAuthDisconnected());
      }
    } catch (e) {
      emit(KisAuthFailure(message: e.toString()));
    }
  }

  Future<void> _onDisconnect(
    KisDisconnectRequested event,
    Emitter<KisAuthState> emit,
  ) async {
    await _repository.disconnect(event.userId);
    emit(const KisAuthDisconnected());
  }
}
