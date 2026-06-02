import 'dart:math';

import '../entities/backtest_result.dart';
import '../entities/candle.dart';
import '../entities/trade_record.dart';
import '../entities/trade_signal.dart';
import 'calculate_vwap.dart';

  /// 백테스트 실행 유스케이스.
///
/// [mode]: 'vwap_poc' (기본) = VWAP+POC 반전 전략
///         'vwap_cross' = VWAP Cross 추세추종 (VWAP 위=Long, 아래=Short)
/// [stopLossPercent]: 손실 N% 도달 시 강제 청산
/// [closeAtEndOfDay]: 장 종료 시 포지션 청산
/// [commissionPercent]: 거래당 수수료 (%)
BacktestResult runBacktest({
  required List<Candle> candles,
  double tickSize = 1.0,
  double stopLossPercent = 0,
  bool closeAtEndOfDay = false,
  String mode = 'vwap_poc',
  double commissionPercent = 0,
}) {
  if (candles.isEmpty) {
    return const BacktestResult(
      trades: [], totalReturn: 0, totalCommission: 0, netReturn: 0,
      winRate: 0, totalSignals: 0, maxDrawdown: 0, sharpeRatio: 0,
    );
  }

  final vwapResult = calculateVwap(candles: candles, tickSize: tickSize);

  final trades = <TradeRecord>[];
  TradeSignal? currentPosition;
  double? entryPrice;
  DateTime? entryTime;
  double totalCommission = 0;

  void closePosition(double exitPrice, DateTime exitTime) {
    if (currentPosition == null || entryPrice == null || entryTime == null) return;
    final rawPnl = _calculatePnl(
      signal: currentPosition!,
      entryPrice: entryPrice!,
      exitPrice: exitPrice,
    );
    final commission = (entryPrice! + exitPrice) * (commissionPercent / 100);
    final netPnl = rawPnl - commission;
    totalCommission += commission;
    trades.add(TradeRecord(
      entryTime: entryTime!,
      exitTime: exitTime,
      entryPrice: entryPrice!,
      exitPrice: exitPrice,
      signal: currentPosition!,
      pnl: netPnl,
    ));
    currentPosition = null;
    entryPrice = null;
    entryTime = null;
  }

  for (int i = 0; i < candles.length; i++) {
    final candle = candles[i];
    final vwap = vwapResult.vwapSeries[i];
    final poc = vwapResult.pocSeries[i];

    // End-of-day check
    final isLastOfDay = closeAtEndOfDay && (i + 1 >= candles.length ||
        candles[i + 1].timestamp.year != candle.timestamp.year ||
        candles[i + 1].timestamp.month != candle.timestamp.month ||
        candles[i + 1].timestamp.day != candle.timestamp.day);

    // Stop Loss
    if (currentPosition != null && stopLossPercent > 0) {
      final pnlPct = _calculatePnlPercent(
        signal: currentPosition!,
        entryPrice: entryPrice ?? 0,
        currentPrice: candle.close,
      );
      if (pnlPct <= -stopLossPercent) {
        closePosition(candle.close, candle.timestamp);
      }
    }

    // 장 마감 청산
    if (currentPosition != null && isLastOfDay) {
      closePosition(candle.close, candle.timestamp);
    }

    if (currentPosition != null) continue;

    final rawSignal = mode == 'vwap_cross'
        ? _vwapCrossSignal(currentPrice: candle.close, vwap: vwap)
        : _vwapPocSignal(currentPrice: candle.close, vwap: vwap, poc: poc);

    if (rawSignal == TradeSignal.neutral) continue;

    currentPosition = rawSignal;
    entryPrice = candle.close;
    entryTime = candle.timestamp;
  }

  // 마지막 포지션 청산
  if (currentPosition != null && entryPrice != null && entryTime != null) {
    final last = candles.last;
    final rawPnl = _calculatePnl(
      signal: currentPosition!,
      entryPrice: entryPrice!,
      exitPrice: last.close,
    );
    final commission = (entryPrice! + last.close) * (commissionPercent / 100);
    totalCommission += commission;
    trades.add(TradeRecord(
      entryTime: entryTime!,
      exitTime: last.timestamp,
      entryPrice: entryPrice!,
      exitPrice: last.close,
      signal: currentPosition!,
      pnl: rawPnl - commission,
    ));
  }

  final totalReturn = trades.fold(0.0, (s, t) => s + t.pnl);
  final wins = trades.where((t) => t.pnl > 0).length;
  final winRate = trades.isEmpty ? 0.0 : wins / trades.length;

  double peak = 0;
  double maxDrawdown = 0;
  double runningPnl = 0;
  for (final t in trades) {
    runningPnl += t.pnl;
    if (runningPnl > peak) peak = runningPnl;
    final dd = peak - runningPnl;
    if (dd > maxDrawdown) maxDrawdown = dd;
  }

  double sharpeRatio = 0;
  if (trades.length > 1) {
    final returns = trades.map((t) => t.pnl).toList();
    final avg = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.map((r) => (r - avg) * (r - avg)).reduce((a, b) => a + b) / returns.length;
    final stdDev = sqrt(variance);
    sharpeRatio = stdDev == 0 ? 0 : avg / stdDev;
  }

  return BacktestResult(
    trades: trades,
    totalReturn: totalReturn + totalCommission,
    totalCommission: totalCommission,
    netReturn: totalReturn,
    winRate: winRate,
    totalSignals: trades.length,
    maxDrawdown: maxDrawdown,
    sharpeRatio: sharpeRatio,
  );
}

/// VWAP+POC 반전 전략: VWAP/POC 둘 다 위=Short, 둘 다 아래=Long
TradeSignal _vwapPocSignal({
  required double currentPrice,
  required double vwap,
  double? poc,
}) {
  if (poc == null) return TradeSignal.neutral;
  final aboveVwap = currentPrice > vwap;
  final abovePoc = currentPrice > poc;
  if (aboveVwap && abovePoc) return TradeSignal.strongSell;
  if (!aboveVwap && !abovePoc) return TradeSignal.strongBuy;
  return TradeSignal.neutral;
}

/// VWAP Cross 추세추종: VWAP 위=Long, 아래=Short
TradeSignal _vwapCrossSignal({
  required double currentPrice,
  required double vwap,
}) {
  if (currentPrice > vwap) return TradeSignal.strongBuy;
  if (currentPrice < vwap) return TradeSignal.strongSell;
  return TradeSignal.neutral;
}

double _calculatePnl({
  required TradeSignal signal,
  required double entryPrice,
  required double exitPrice,
}) {
  return signal == TradeSignal.strongBuy
      ? exitPrice - entryPrice
      : entryPrice - exitPrice;
}

double _calculatePnlPercent({
  required TradeSignal signal,
  required double entryPrice,
  required double currentPrice,
}) {
  if (entryPrice == 0) return 0;
  final pnl = _calculatePnl(signal: signal, entryPrice: entryPrice, exitPrice: currentPrice);
  return pnl / entryPrice * 100;
}
