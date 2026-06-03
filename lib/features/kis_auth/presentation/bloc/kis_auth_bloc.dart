import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/kis_auth_repository.dart';
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
}
