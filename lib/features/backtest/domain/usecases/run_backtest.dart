import 'dart:math';

import '../entities/backtest_result.dart';
import '../entities/candle.dart';
import '../entities/trade_record.dart';
import '../entities/trade_signal.dart';
import 'calculate_vwap.dart';
import 'indicators.dart';

/// 백테스트 실행 유스케이스.
///
/// [mode]: 'vwap_poc' (기본) = VWAP+POC 반전 전략
///         'vwap_cross' = VWAP Cross 추세추종
/// [adaptiveMode]: true = Choppiness Index로 전략/RSI/ATR 자동 조정
/// [stopLossPercent]: 손실 N% 도달 시 강제 청산 (0=미사용)
/// [useAtrStop]: ATR 기반 손절 사용 (stopLossPercent 대체)
/// [atrMultiplier]: ATR × N 배율 (기본 2.0)
/// [useRsiFilter]: RSI 필터 사용 여부
/// [rsiOversold]: RSI 이하 → Long 금지 (기본 30)
/// [rsiOverbought]: RSI 이상 → Short 금지 (기본 70)
/// [entryThresholdTicks]: VWAP과 N틱 이상 떨어져야 진입 (0=즉시 진입)
/// [takeProfitTicks]: 익절 틱 수 (0=미사용)
/// [stopLossTicks]: 손절 틱 수 (0=미사용, 기존 stopLossPercent 유지)
/// [tradeStartTime]: 거래 시작 시간 (HHMM, 예: 1000, 0=장 시작)
/// [tradeEndTime]: 거래 종료 시간 (HHMM, 예: 1430, 2400=장 종료)
/// [closeAtEndOfDay]: 장 종료 시 포지션 청산
/// [commissionPercent]: 거래당 수수료 (%)
/// mode='vwap_cross': VWAP Cross 추세추종
/// mode='vwap_poc': VWAP+POC 반전 전략
/// mode='macd': MACD(12,26,9) 골든/데드크로스
/// mode='obv_div': OBV 다이버전스
BacktestResult runBacktest({
  required List<Candle> candles,
  double tickSize = 1.0,
  bool adaptiveMode = false,
  double entryThresholdTicks = 0,
  double takeProfitTicks = 0,
  double stopLossTicks = 0,
  double stopLossPercent = 0,
  bool useAtrStop = false,
  double atrMultiplier = 2.0,
  bool useRsiFilter = false,
  double rsiOversold = 30,
  double rsiOverbought = 70,
  int tradeStartTime = 0,
  int tradeEndTime = 2400,
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
  final rsi = useRsiFilter || adaptiveMode ? calculateRsi(candles) : <double>[];
  final atr = useAtrStop || adaptiveMode ? calculateAtr(candles) : <double>[];
  final ci = adaptiveMode ? calculateChoppinessIndex(candles) : <double>[];
  final macdSig = (mode == 'macd') ? calculateMacdSignal(candles) : <int>[];
  final obvSig = (mode == 'obv_div') ? calculateObvDivergence(candles) : <int>[];

  // Adaptive: ATR 기준 RSI 임계값 자동 조정용
  final atrAvg = atr.isEmpty ? 0 : atr.skip(atr.length ~/ 2).reduce((a, b) => a + b) / (atr.length ~/ 2);

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

    final isLastOfDay = closeAtEndOfDay && (i + 1 >= candles.length ||
        candles[i + 1].timestamp.year != candle.timestamp.year ||
        candles[i + 1].timestamp.month != candle.timestamp.month ||
        candles[i + 1].timestamp.day != candle.timestamp.day);

    // TP/SL 기반 청산 (Long=고가/저가, Short=저가/고가)
    if (currentPosition != null && (takeProfitTicks > 0 || stopLossTicks > 0)) {
      final tpPrice = currentPosition == TradeSignal.strongBuy
          ? candle.high : candle.low;
      final slPrice = currentPosition == TradeSignal.strongBuy
          ? candle.low : candle.high;
      final tpPnl = _calculatePnl(signal: currentPosition!, entryPrice: entryPrice ?? 0, exitPrice: tpPrice);
      final slPnl = _calculatePnl(signal: currentPosition!, entryPrice: entryPrice ?? 0, exitPrice: slPrice);
      if (takeProfitTicks > 0 && tpPnl >= takeProfitTicks * tickSize) {
        closePosition(tpPrice, candle.timestamp);
      } else if (stopLossTicks > 0 && slPnl <= -(stopLossTicks * tickSize)) {
        closePosition(slPrice, candle.timestamp);
      }
    }

    // ATR 기반 손절 (adaptive: 배율 자동 조정)
    if (currentPosition != null && useAtrStop && i < atr.length) {
      final atrVal = atr[i];
      if (atrVal > 0) {
        final mult = adaptiveMode ? (atrAvg > 0 ? atrMultiplier * (atrVal / atrAvg) : atrMultiplier) : atrMultiplier;
        final threshold = atrVal * mult;
        final pnlLoss = _calculatePnl(
          signal: currentPosition!,
          entryPrice: entryPrice ?? 0,
          exitPrice: candle.close,
        );
        if (pnlLoss.abs() >= threshold) {
          closePosition(candle.close, candle.timestamp);
        }
      }
    }

    // 퍼센트 기반 손절
    if (currentPosition != null && !useAtrStop && stopLossPercent > 0) {
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

    // 시간 필터: 지정된 시간대에만 진입
    if (tradeStartTime > 0 || tradeEndTime < 2400) {
      final t = candle.timestamp;
      final timeInt = t.hour * 100 + t.minute;
      if (timeInt < tradeStartTime || timeInt > tradeEndTime) continue;
    }

    // Adaptive: Choppiness Index로 전략 자동 선택
    String effectiveMode = mode;
    double ob = rsiOverbought;
    double os = rsiOversold;

    if (adaptiveMode && i < ci.length && i < atr.length) {
      final ciVal = ci[i];
      final atrRatio = atrAvg > 0 ? atr[i] / atrAvg : 1.0;
      effectiveMode = ciVal > 61.8 ? 'vwap_poc' : 'vwap_cross';

      final levels = adaptiveRsiLevels(atrRatio: atrRatio, rsiBase: 70);
      ob = levels.$1;
      os = levels.$2;
    }

    TradeSignal rawSignal;
    switch (effectiveMode) {
      case 'macd':
        rawSignal = i < macdSig.length
            ? (macdSig[i] == 1 ? TradeSignal.strongBuy :
               macdSig[i] == 2 ? TradeSignal.strongSell : TradeSignal.neutral)
            : TradeSignal.neutral;
        break;
      case 'obv_div':
        rawSignal = i < obvSig.length
            ? (obvSig[i] == 1 ? TradeSignal.strongBuy :
               obvSig[i] == 2 ? TradeSignal.strongSell : TradeSignal.neutral)
            : TradeSignal.neutral;
        break;
      case 'vwap_poc':
        rawSignal = _vwapPocSignal(currentPrice: candle.close, vwap: vwap, poc: poc);
        break;
      default: // vwap_cross
        rawSignal = _vwapCrossSignal(currentPrice: candle.close, vwap: vwap);
    }

    if (rawSignal == TradeSignal.neutral) continue;

    // 진입 임계값: VWAP과 N틱 이상 떨어져야 진입
    if (entryThresholdTicks > 0) {
      final dist = (candle.close - vwap).abs();
      if (dist < entryThresholdTicks * tickSize) continue;
    }

    // RSI 필터
    if ((useRsiFilter || adaptiveMode) && i < rsi.length) {
      final rsiVal = rsi[i];
      if (rawSignal == TradeSignal.strongBuy && rsiVal > ob) continue;
      if (rawSignal == TradeSignal.strongSell && rsiVal < os) continue;
    }

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
