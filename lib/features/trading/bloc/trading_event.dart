import 'package:equatable/equatable.dart';

abstract class TradingEvent extends Equatable {
  const TradingEvent();
  @override
  List<Object?> get props => [];
}

class TradingBuyRequested extends TradingEvent {
  const TradingBuyRequested({
    required this.symbol,
    required this.quantity,
    required this.price,
    this.orderDivision = '00',
  });
  final String symbol;
  final int quantity;
  final double price;
  final String orderDivision;

  @override
  List<Object?> get props => [symbol, quantity, price, orderDivision];
}

class TradingSellRequested extends TradingEvent {
  const TradingSellRequested({
    required this.symbol,
    required this.quantity,
    required this.price,
    this.orderDivision = '00',
  });
  final String symbol;
  final int quantity;
  final double price;
  final String orderDivision;

  @override
  List<Object?> get props => [symbol, quantity, price, orderDivision];
}

class TradingCancelRequested extends TradingEvent {
  const TradingCancelRequested({
    required this.orgOrderNo,
    required this.symbol,
    required this.quantity,
    required this.price,
  });
  final String orgOrderNo;
  final String symbol;
  final int quantity;
  final double price;

  @override
  List<Object?> get props => [orgOrderNo, symbol, quantity, price];
}

class TradingFetchOrders extends TradingEvent {
  const TradingFetchOrders({
    required this.startDate,
    required this.endDate,
  });
  final String startDate;
  final String endDate;

  @override
  List<Object?> get props => [startDate, endDate];
}

class TradingFetchPositions extends TradingEvent {
  const TradingFetchPositions();
}

class TradingSymbolChanged extends TradingEvent {
  const TradingSymbolChanged(this.symbol);
  final String symbol;

  @override
  List<Object?> get props => [symbol];
}

class TradingClearMessage extends TradingEvent {
  const TradingClearMessage();
}
