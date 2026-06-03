import 'package:equatable/equatable.dart';

sealed class BacktestEvent extends Equatable {
  const BacktestEvent();
  @override
  List<Object?> get props => [];
}

class BacktestLoadData extends BacktestEvent {
  final String symbol;
  final DateTime startDate;
  final DateTime endDate;
  final bool isMinute;
  final String appKey;
  final String appSecret;
  final bool isPaper;
  const BacktestLoadData({
    required this.symbol,
    required this.startDate,
    required this.endDate,
    required this.isMinute,
    required this.appKey,
    required this.appSecret,
    required this.isPaper,
  });
  @override
  List<Object?> get props => [symbol, startDate, endDate, isMinute];
}

class BacktestRun extends BacktestEvent {
  final double tickSize;
  final bool adaptiveMode;
  final double entryThresholdTicks;
  final double takeProfitTicks;
  final double stopLossTicks;
  final double stopLossPercent;
  final bool useAtrStop;
  final double atrMultiplier;
  final bool useRsiFilter;
  final double rsiOversold;
  final double rsiOverbought;
  final String mode;
  final double commissionPercent;
  final String symbol;
  const BacktestRun({
    required this.tickSize,
    required this.adaptiveMode,
    required this.entryThresholdTicks,
    required this.takeProfitTicks,
    required this.stopLossTicks,
    required this.stopLossPercent,
    required this.useAtrStop,
    required this.atrMultiplier,
    required this.useRsiFilter,
    required this.rsiOversold,
    required this.rsiOverbought,
    required this.mode,
    required this.commissionPercent,
    required this.symbol,
  });
  @override
  List<Object?> get props => [tickSize, adaptiveMode, entryThresholdTicks, takeProfitTicks, stopLossTicks];
}

class BacktestDeleteCache extends BacktestEvent {
  final String symbol;
  final DateTime startDate;
  final DateTime endDate;
  final double tickSize;
  const BacktestDeleteCache({
    required this.symbol,
    required this.startDate,
    required this.endDate,
    required this.tickSize,
  });
  @override
  List<Object?> get props => [symbol, tickSize];
}
