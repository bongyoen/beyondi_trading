import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/features/kis_auth/api/kis_auth_repository.dart';
import 'kis_auth_event.dart';
import 'kis_auth_state.dart';

class KisAuthBloc extends Bloc<KisAuthEvent, KisAuthState> {
  KisAuthBloc({required KisAuthRepository repository})
      : _repository = repository,
        super(const KisAuthInitial()) {
    on<KisConnectRequested>(_onConnect);
    on<KisStatusRequested>(_onStatus);
    on<KisDisconnectRequested>(_onDisconnect);
    on<KisToggleEnv>(_onToggle);
    on<KisRefreshRequested>(_onRefresh);
  }

  final KisAuthRepository _repository;

  Future<void> _onConnect(KisConnectRequested event, Emitter<KisAuthState> emit) async {
    emit(const KisAuthLoading());
    try {
      final connection = await _repository.connect(
        userId: event.userId,
        mockKey: event.mockKey, mockSecret: event.mockSecret,
        mockAccountNo: event.mockAccountNo, mockProductCode: event.mockProductCode,
        realKey: event.realKey, realSecret: event.realSecret,
        realAccountNo: event.realAccountNo, realProductCode: event.realProductCode,
      );
      emit(KisAuthConnected(connection: connection));
    } catch (e) {
      emit(KisAuthFailure(message: e.toString()));
    }
  }

  Future<void> _onStatus(KisStatusRequested event, Emitter<KisAuthState> emit) async {
    // 이미 연결되어 있고 토큰이 유효하면 Worker 조회 스킵
    if (state is KisAuthConnected) {
      final cur = (state as KisAuthConnected).connection;
      if (cur.isTokenValid) return;
    }
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

  Future<void> _onDisconnect(KisDisconnectRequested event, Emitter<KisAuthState> emit) async {
    await _repository.disconnect(event.userId);
    emit(const KisAuthDisconnected());
  }

  void _onToggle(KisToggleEnv event, Emitter<KisAuthState> emit) {
    final current = state;
    if (current is KisAuthConnected) {
      emit(KisAuthConnected(connection: current.connection.copyWith(useMock: event.useMock)));
    }
  }

  Future<void> _onRefresh(KisRefreshRequested event, Emitter<KisAuthState> emit) async {
    // 1분 이내 재시도 → 거절
    if (state is KisAuthConnected) {
      final cur = (state as KisAuthConnected).connection;
      final ca = cur.active?.connectedAt;
      if (ca != null && DateTime.now().difference(ca).inSeconds < 60) {
        emit(KisAuthFailure(
          message: '갱신은 ${60 - DateTime.now().difference(ca).inSeconds}초 후에 가능합니다',
        ));
        return;
      }
    }
    emit(const KisAuthLoading());
    try {
      final connection = await _repository.refreshToken(event.userId);
      emit(KisAuthConnected(connection: connection));
    } catch (e) {
      emit(KisAuthFailure(message: e.toString()));
    }
  }
}
