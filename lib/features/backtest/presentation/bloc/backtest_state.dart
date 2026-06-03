import 'package:equatable/equatable.dart';

import '../../../backtest/domain/entities/backtest_result.dart';
import '../../../backtest/domain/entities/candle.dart';

sealed class BacktestState extends Equatable {
  const BacktestState();
  @override
  List<Object?> get props => [];
}

class BacktestInitial extends BacktestState {
  const BacktestInitial();
}

class BacktestDataLoading extends BacktestState {
  final String status;
  final List<Candle> candles;
  const BacktestDataLoading({this.status = '', this.candles = const []});
  @override
  List<Object?> get props => [status, candles.length];
}

class BacktestDataLoaded extends BacktestState {
  final String status;
  final List<Candle> candles;
  const BacktestDataLoaded({required this.candles, this.status = ''});
  @override
  List<Object?> get props => [candles.length, status];
}

class BacktestRunning extends BacktestState {
  final String status;
  final List<Candle> candles;
  const BacktestRunning({required this.candles, this.status = '백테스트 실행 중...'});
  @override
  List<Object?> get props => [candles.length, status];
}

class BacktestCompleted extends BacktestState {
  final String status;
  final List<Candle> candles;
  final BacktestResult result;
  const BacktestCompleted({required this.candles, required this.result, this.status = ''});
  @override
  List<Object?> get props => [candles.length, result.netReturn];
}

class BacktestError extends BacktestState {
  final String message;
  final List<Candle>? candles;
  const BacktestError({required this.message, this.candles});
  @override
  List<Object?> get props => [message, candles?.length];
}
