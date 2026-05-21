import 'dart:math';

import '../entities/backtest_result.dart';
import '../entities/candle.dart';
import '../entities/trade_record.dart';
import '../entities/trade_signal.dart';
import 'calculate_vwap.dart';

/// VWAP + 거래량 프로파일 기반 백테스트 실행 유스케이스.
///
/// 규칙:
///   - 현재가 > VWAP && 현재가 > POC → 강한 매도 신호 (short 진입)
///   - 현재가 < VWAP && 현재가 < POC → 강한 매수 신호 (long 진입)
///   - 그 외 → 중립 (포지션 유지 또는 미진입)
///
/// Atomic Predictability: 동일한 캔들 데이터 → 동일한 결과.
BacktestResult runBacktest({
  required List<Candle> candles,
  double tickSize = 1.0,
}) {
  if (candles.isEmpty) {
    return const BacktestResult(
      trades: [],
      totalReturn: 0,
      winRate: 0,
      totalSignals: 0,
      maxDrawdown: 0,
      sharpeRatio: 0,
    );
  }

  // 1. VWAP + POC 시리즈 미리 계산
  final vwapResult = calculateVwap(candles: candles, tickSize: tickSize);

  // 2. 캔들 순회하며 신호 생성 및 포지션 트래킹
  final trades = <TradeRecord>[];
  TradeSignal? currentPosition;
  double? entryPrice;
  DateTime? entryTime;

  for (int i = 0; i < candles.length; i++) {
    final candle = candles[i];
    final vwap = vwapResult.vwapSeries[i];
    final poc = vwapResult.pocSeries[i];

    // 신호 결정
    final signal = _determineSignal(
      currentPrice: candle.close,
      vwap: vwap,
      poc: poc,
    );

    if (signal == TradeSignal.neutral) {
      continue; // 중립: 아무 것도 하지 않음
    }

    if (currentPosition == null) {
      // 포지션 없음 → 신호 방향으로 진입
      currentPosition = signal;
      entryPrice = candle.close;
      entryTime = candle.timestamp;
    } else if (signal != currentPosition) {
      // 반대 신호 → 기존 포지션 청산 후 반대 방향 진입
      final pnl = _calculatePnl(
        signal: currentPosition,
        entryPrice: entryPrice!,
        exitPrice: candle.close,
      );

      trades.add(TradeRecord(
        entryTime: entryTime!,
        exitTime: candle.timestamp,
        entryPrice: entryPrice,
        exitPrice: candle.close,
        signal: currentPosition,
        pnl: pnl,
      ));

      // 반대 방향으로 새 포지션 진입
      currentPosition = signal;
      entryPrice = candle.close;
      entryTime = candle.timestamp;
    }
    // 같은 신호면 포지션 유지 (hold)
  }

  // 3. 마지막 포지션 청산 (마지막 캔들 종가 기준)
  if (currentPosition != null && entryPrice != null && entryTime != null) {
    final lastCandle = candles.last;
    final pnl = _calculatePnl(
      signal: currentPosition,
      entryPrice: entryPrice,
      exitPrice: lastCandle.close,
    );

    trades.add(TradeRecord(
      entryTime: entryTime,
      exitTime: lastCandle.timestamp,
      entryPrice: entryPrice,
      exitPrice: lastCandle.close,
      signal: currentPosition,
      pnl: pnl,
    ));
  }

  // 4. 통계 계산
  final totalReturn = trades.fold(0.0, (sum, t) => sum + t.pnl);
  final wins = trades.where((t) => t.pnl > 0).length;
  final winRate = trades.isEmpty ? 0.0 : wins / trades.length;

  // Max Drawdown
  double peak = 0;
  double maxDrawdown = 0;
  double runningPnl = 0;
  for (final trade in trades) {
    runningPnl += trade.pnl;
    if (runningPnl > peak) peak = runningPnl;
    final drawdown = peak - runningPnl;
    if (drawdown > maxDrawdown) maxDrawdown = drawdown;
  }

  // Sharpe Ratio (단순화: 평균 수익률 / 표준편차)
  double sharpeRatio = 0;
  if (trades.length > 1) {
    final returns = trades.map((t) => t.pnl).toList();
    final avgReturn = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns
            .map((r) => (r - avgReturn) * (r - avgReturn))
            .reduce((a, b) => a + b) /
        returns.length;
    final stdDev = sqrt(variance);
    sharpeRatio = stdDev == 0 ? 0 : avgReturn / stdDev;
  }

  return BacktestResult(
    trades: trades,
    totalReturn: totalReturn,
    winRate: winRate,
    totalSignals: trades.length,
    maxDrawdown: maxDrawdown,
    sharpeRatio: sharpeRatio,
  );
}

/// VWAP + POC 기반 매매 신호 판단.
///
/// - 현재가 > VWAP && 현재가 > POC → strongSell
/// - 현재가 < VWAP && 현재가 < POC → strongBuy
/// - 그 외 → neutral
TradeSignal _determineSignal({
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

/// 포지션 방향에 따른 손익 계산.
///
/// - strongBuy (long):  exitPrice - entryPrice
/// - strongSell (short): entryPrice - exitPrice
double _calculatePnl({
  required TradeSignal signal,
  required double entryPrice,
  required double exitPrice,
}) {
  return signal == TradeSignal.strongBuy
      ? exitPrice - entryPrice
      : entryPrice - exitPrice;
}
