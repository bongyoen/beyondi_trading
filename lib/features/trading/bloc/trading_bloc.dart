import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beyondi_trading/features/trading/api/trading_repository.dart';
import 'trading_event.dart';
import 'trading_state.dart';

class TradingBloc extends Bloc<TradingEvent, TradingState> {
  TradingBloc({
    required TradingRepository repository,
    required String accountNo,
    required String productCode,
  })  : _repo = repository,
        _accountNo = accountNo,
        _productCode = productCode,
        super(const TradingInitial()) {
    on<TradingBuyRequested>(_onBuy);
    on<TradingSellRequested>(_onSell);
    on<TradingCancelRequested>(_onCancel);
    on<TradingFetchOrders>(_onFetchOrders);
    on<TradingFetchPositions>(_onFetchPositions);
    on<TradingSymbolChanged>(_onSymbolChanged);
    on<TradingClearMessage>(_onClearMessage);
  }

  final TradingRepository _repo;
  final String _accountNo;
  final String _productCode;

  Future<void> _onBuy(
      TradingBuyRequested event, Emitter<TradingState> emit) async {
    emit(TradingLoading());
    try {
      final result = await _repo.placeBuyOrder(
        accountNo: _accountNo,
        productCode: _productCode,
        symbol: event.symbol,
        quantity: event.quantity,
        price: event.price,
        orderDivision: event.orderDivision,
      );
      final pos = await _repo.fetchPositions(
        accountNo: _accountNo,
        productCode: _productCode,
      );
      emit(TradingLoaded(
        positions: pos,
        orders: const [],
        lastOrderResult: result,
        selectedSymbol: event.symbol,
      ));
    } catch (e) {
      emit(TradingLoaded(
        positions: (state is TradingLoaded) ? (state as TradingLoaded).positions : [],
        error: e.toString(),
        selectedSymbol: event.symbol,
      ));
    }
  }

  Future<void> _onSell(
      TradingSellRequested event, Emitter<TradingState> emit) async {
    emit(TradingLoading());
    try {
      final result = await _repo.placeSellOrder(
        accountNo: _accountNo,
        productCode: _productCode,
        symbol: event.symbol,
        quantity: event.quantity,
        price: event.price,
        orderDivision: event.orderDivision,
      );
      final pos = await _repo.fetchPositions(
        accountNo: _accountNo,
        productCode: _productCode,
      );
      emit(TradingLoaded(
        positions: pos,
        orders: const [],
        lastOrderResult: result,
        selectedSymbol: event.symbol,
      ));
    } catch (e) {
      emit(TradingLoaded(
        positions: (state is TradingLoaded) ? (state as TradingLoaded).positions : [],
        error: e.toString(),
        selectedSymbol: event.symbol,
      ));
    }
  }

  Future<void> _onCancel(
      TradingCancelRequested event, Emitter<TradingState> emit) async {
    emit(TradingLoading());
    try {
      await _repo.cancelOrder(
        accountNo: _accountNo,
        productCode: _productCode,
        orgOrderNo: event.orgOrderNo,
        symbol: event.symbol,
        quantity: event.quantity,
        price: event.price,
      );
      final pos = await _repo.fetchPositions(
        accountNo: _accountNo,
        productCode: _productCode,
      );
      emit(TradingLoaded(positions: pos));
    } catch (e) {
      emit(TradingLoaded(
        positions: (state is TradingLoaded) ? (state as TradingLoaded).positions : [],
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFetchOrders(
      TradingFetchOrders event, Emitter<TradingState> emit) async {
    try {
      final orders = await _repo.fetchDailyOrders(
        accountNo: _accountNo,
        productCode: _productCode,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(TradingLoaded(
        positions: (state is TradingLoaded) ? (state as TradingLoaded).positions : [],
        orders: orders,
        selectedSymbol: (state is TradingLoaded) ? (state as TradingLoaded).selectedSymbol : '',
      ));
    } catch (e) {
      emit(TradingLoaded(
        positions: (state is TradingLoaded) ? (state as TradingLoaded).positions : [],
        orders: (state is TradingLoaded) ? (state as TradingLoaded).orders : [],
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFetchPositions(
      TradingFetchPositions event, Emitter<TradingState> emit) async {
    try {
      final pos = await _repo.fetchPositions(
        accountNo: _accountNo,
        productCode: _productCode,
      );
      emit(TradingLoaded(
        positions: pos,
        orders: (state is TradingLoaded) ? (state as TradingLoaded).orders : [],
        selectedSymbol: (state is TradingLoaded) ? (state as TradingLoaded).selectedSymbol : '',
      ));
    } catch (e) {
      emit(TradingLoaded(
        orders: (state is TradingLoaded) ? (state as TradingLoaded).orders : [],
        error: e.toString(),
      ));
    }
  }

  void _onSymbolChanged(
      TradingSymbolChanged event, Emitter<TradingState> emit) {
    if (state is TradingLoaded) {
      final s = state as TradingLoaded;
      emit(TradingLoaded(
        positions: s.positions,
        orders: s.orders,
        lastOrderResult: s.lastOrderResult,
        error: s.error,
        selectedSymbol: event.symbol,
      ));
    }
  }

  void _onClearMessage(
      TradingClearMessage event, Emitter<TradingState> emit) {
    if (state is TradingLoaded) {
      final s = state as TradingLoaded;
      emit(TradingLoaded(
        positions: s.positions,
        orders: s.orders,
        selectedSymbol: s.selectedSymbol,
      ));
    }
  }
}
