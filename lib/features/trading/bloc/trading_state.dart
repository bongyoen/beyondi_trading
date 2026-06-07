import 'package:equatable/equatable.dart';
import 'package:beyondi_trading/entities/order_record/model/order_record.dart';
import 'package:beyondi_trading/entities/trading_position/model/trading_position.dart';

abstract class TradingState extends Equatable {
  const TradingState();
  @override
  List<Object?> get props => [];
}

class TradingInitial extends TradingState {
  const TradingInitial();
}

class TradingLoading extends TradingState {
  const TradingLoading();
}

class TradingLoaded extends TradingState {
  const TradingLoaded({
    this.positions = const [],
    this.orders = const [],
    this.lastOrderResult,
    this.error,
    this.selectedSymbol = '',
  });
  final List<TradingPosition> positions;
  final List<OrderRecord> orders;
  final Map<String, dynamic>? lastOrderResult;
  final String? error;
  final String selectedSymbol;

  bool get hasPositions => positions.isNotEmpty;
  bool get hasOrders => orders.isNotEmpty;

  TradingPosition? positionFor(String symbol) {
    try {
      return positions.firstWhere((p) => p.symbol == symbol);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props =>
      [positions, orders, lastOrderResult, error, selectedSymbol];
}
