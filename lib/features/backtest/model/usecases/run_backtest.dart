import 'dart:math';

import 'package:beyondi_trading/entities/backtest_result/model/backtest_result.dart';
import 'package:beyondi_trading/entities/candle/model/candle.dart';
import 'package:beyondi_trading/entities/trade_record/model/trade_record.dart';
import 'package:beyondi_trading/entities/trade_signal/model/trade_signal.dart';
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
/// [principal]: 투자 원금 (0=1주 모드, >0=원금 기반 포지션 사이징)
/// [longOnly]: true = Long 신호만 진입 (Short 무시)
/// [consecutiveLossLimit]: 연속 N회 손실 시 거래 중단 (0=off)
/// [dailyLossLimit]: 일일 누적 손실 N원 도달 시 거래 중단 (0=off)
/// [maxTotalLoss]: 전체 누적 손실 N원 도달 시 전면 중단 (0=off)
/// [commissionPercent]: 거래당 수수료 (%)
/// mode='vwap_cross': VWAP Cross 추세추종
/// mode='vwap_poc': VWAP+POC 반전 전략
/// mode='macd': MACD(12,26,9) 골든/데드크로스
/// mode='obv_div': OBV 다이버전스
/// mode='hybrid': CI 기반 cross/poc 자동 전환
/// mode='vwap_scalp': VWAP 위 + RSI(2) 과매도 + volume 확인 + VWAP 근접 → Long Only 스캘핑
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
  double principal = 0,
  bool longOnly = false,
  int consecutiveLossLimit = 0,
  double dailyLossLimit = 0,
  double maxTotalLoss = 0,
  bool useAtrPositionSizing = false,
  // vwap_scalp 전용 파라미터
  int scalpRsiPeriod = 2,
  double scalpRsiThreshold = 30,
  double scalpVolumeMultiplier = 1.5,
  double scalpEntryTicksMin = 5,
  double scalpEntryTicksMax = 15,
  int scalpMaxHoldMinutes = 30,
  double scalpStopLossTicks = 3,
  // ORB 전용 파라미터
  int orbRangeMinutes = 30,
  double orbStopPercent = 0.005,
  // EMA Trend 전용 파라미터
  int emaFastPeriod = 9,
  int emaSlowPeriod = 21,
  double adxThreshold = 25,
}) {
  if (candles.isEmpty) {
    return const BacktestResult(
      trades: [], totalReturn: 0, totalCommission: 0, netReturn: 0,
      winRate: 0, totalSignals: 0, maxDrawdown: 0, sharpeRatio: 0, equityCurve: [],
    );
  }

  final vwapResult = calculateVwap(candles: candles, tickSize: tickSize);
  final rsi = useRsiFilter || adaptiveMode ? calculateRsi(candles) : <double>[];
  final atr = useAtrStop || adaptiveMode || useAtrPositionSizing ? calculateAtr(candles) : <double>[];
  final ci = adaptiveMode ? calculateChoppinessIndex(candles) : <double>[];
  final macdSig = (mode == 'macd') ? calculateMacdSignal(candles) : <int>[];
  final obvSig = (mode == 'obv_div') ? calculateObvDivergence(candles) : <int>[];
  final hybridCi = (mode == 'hybrid') ? calculateChoppinessIndex(candles) : <double>[];
  final rsi2 = (mode == 'vwap_scalp') ? calculateRsi(candles, period: scalpRsiPeriod) : <double>[];
  final closes = candles.map((c) => c.close).toList();
  final emaFast = (mode == 'ema_trend') ? calculateEma(closes, emaFastPeriod) : <double>[];
  final emaSlow = (mode == 'ema_trend') ? calculateEma(closes, emaSlowPeriod) : <double>[];
  final adx = (mode == 'ema_trend') ? calculateAdx(candles) : <double>[];

  // Adaptive: ATR 기준 RSI 임계값 자동 조정용
  final atrAvg = atr.isEmpty ? 0 : atr.skip(atr.length ~/ 2).reduce((a, b) => a + b) / (atr.length ~/ 2);

  // vwap_scalp: 1일(390분) 슬라이딩 평균 거래량(O(n)) + 일중 VWAP
  // ORB (Phase 2): 거래량 급증 필터용 rolling avg vol
  final rollingAvgVol = <double>[];
  final intradayVwap = <double>[];
  final needVol = mode == 'vwap_scalp' || mode == 'orb';
  if (needVol) {
    double winVol = 0;
    double dayTpv = 0, dayVol = 0;
    String curDay = '';
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      if (mode == 'vwap_scalp') {
        final dk = '${c.timestamp.year}-${c.timestamp.month}-${c.timestamp.day}';
        if (dk != curDay) { dayTpv = 0; dayVol = 0; curDay = dk; }
        final tp = (c.high + c.low + c.close) / 3;
        dayTpv += tp * c.volume;
        dayVol += c.volume;
        intradayVwap.add(dayVol > 0 ? dayTpv / dayVol : c.close);
      }
      winVol += c.volume;
      if (i >= 390) winVol -= candles[i - 390].volume;
      rollingAvgVol.add(i < 390 ? winVol / (i + 1) : winVol / 390);
    }
  }

  final trades = <TradeRecord>[];
  TradeSignal? currentPosition;
  double? entryPrice;
  DateTime? entryTime;
  int entryPositionSize = 0;
  double totalCommission = 0;
  int consecutiveLosses = 0;
  double dailyPnl = 0;
  int lastTradeDay = -1;
  bool stoppedByMaxLoss = false;
  // ORB state
  double dayRangeHigh = 0, dayRangeLow = 0;
  int orbRangeMinuteElapsed = 0;
  bool orbRangeComplete = false;
  List<bool> orbIntraday = [false, false, false, false, false]; // unused but referenced

  void closePosition(double exitPrice, DateTime exitTime) {
    if (currentPosition == null || entryPrice == null || entryTime == null) return;
    final pos = entryPositionSize > 0 ? entryPositionSize : max(1, (principal / entryPrice!).floor());
    final rawPnl = _calculatePnl(
      signal: currentPosition!,
      entryPrice: entryPrice!,
      exitPrice: exitPrice,
    ) * pos;
    final commission = (entryPrice! + exitPrice) * pos * (commissionPercent / 100);
    final netPnl = rawPnl - commission;
    totalCommission += commission;
    dailyPnl += netPnl;
    if (netPnl < 0) consecutiveLosses++; else consecutiveLosses = 0;
    trades.add(TradeRecord(
      entryTime: entryTime!,
      exitTime: exitTime,
      entryPrice: entryPrice!,
      exitPrice: exitPrice,
      signal: currentPosition!,
      pnl: netPnl,
      commission: commission,
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

    // vwap_scalp exit checks (intraday VWAP 기준)
    if (currentPosition != null && mode == 'vwap_scalp' && i < intradayVwap.length) {
      final iVwap = intradayVwap[i];
      // VWAP 터치 시 익절
      if (candle.close >= iVwap) { closePosition(iVwap, candle.timestamp); }
      // VWAP 아래 N틱 손절
      else if (scalpStopLossTicks > 0 && candle.close < iVwap - scalpStopLossTicks * tickSize) {
        closePosition(candle.close, candle.timestamp);
      }
      // 시간 기반 청산
      else if (entryTime != null && scalpMaxHoldMinutes > 0 &&
               candle.timestamp.difference(entryTime!).inMinutes >= scalpMaxHoldMinutes) {
        closePosition(candle.close, candle.timestamp);
      }
    }

    // 장 마감 청산
    if (currentPosition != null && isLastOfDay) {
      closePosition(candle.close, candle.timestamp);
    }

    if (currentPosition != null) continue;

    // === 손절 기준 체크 (청산 후 진입 전) ===

    // 일일 손실 리셋 (새 거래일)
    final dayKey = candle.timestamp.year * 10000 + candle.timestamp.month * 100 + candle.timestamp.day;
    if (dayKey != lastTradeDay) {
      lastTradeDay = dayKey;
      dailyPnl = 0;
    }

    // 전체 손실 체크
    if (maxTotalLoss > 0 && trades.fold(0.0, (s, t) => s + t.pnl) <= -maxTotalLoss) {
      stoppedByMaxLoss = true; continue;
    }

    // 중단 조건 체크
    if (stoppedByMaxLoss) continue;
    if (dailyLossLimit > 0 && dailyPnl <= -dailyLossLimit) continue;
    if (consecutiveLossLimit > 0 && consecutiveLosses >= consecutiveLossLimit) continue;

    // 시간 필터: 지정된 시간대에만 진입
    if (tradeStartTime > 0 || tradeEndTime < 2400) {
      final t = candle.timestamp;
      final timeInt = t.hour * 100 + t.minute;
      if (timeInt < tradeStartTime || timeInt > tradeEndTime) continue;
    }

    // ORB: 일별 레인지 트래킹 (N분간 고가/저가 기록)
    bool isNewDay = i == 0 || candles[i].timestamp.day != candles[i-1].timestamp.day;
    if (mode == 'orb') {
      if (isNewDay) {
        for (int oi = 0; oi < orbIntraday.length; oi++) orbIntraday[oi] = false;
        dayRangeHigh = candle.close;
        dayRangeLow = candle.close;
        orbRangeMinuteElapsed = 0;
      }
      if (!orbRangeComplete) {
        orbRangeMinuteElapsed++;
        if (candle.close > dayRangeHigh) dayRangeHigh = candle.close;
        if (candle.close < dayRangeLow) dayRangeLow = candle.close;
        if (orbRangeMinuteElapsed >= orbRangeMinutes) orbRangeComplete = true;
      }
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
    String actualMode = effectiveMode;

    // Hybrid: CI 기반 실시간 전략 선택
    if (effectiveMode == 'hybrid' && i < hybridCi.length) {
      final ciVal = hybridCi[i];
      actualMode = ciVal > 50 ? 'vwap_poc' : 'vwap_cross';
    }

    switch (actualMode) {
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
      case 'vwap_scalp':
        rawSignal = TradeSignal.neutral;
        if (i >= scalpRsiPeriod && i < rsi2.length && i < rollingAvgVol.length && i < intradayVwap.length) {
          final iVwap = intradayVwap[i];
          final rsi2Val = rsi2[i];
          final volOk = candles[i].volume >= rollingAvgVol[i] * scalpVolumeMultiplier;
          final aboveVwap = candle.close > iVwap;
          final ticksFromVwap = (iVwap - candle.close).abs() / tickSize;
          final distOk = ticksFromVwap >= scalpEntryTicksMin && ticksFromVwap <= scalpEntryTicksMax;
          if (aboveVwap && rsi2Val < scalpRsiThreshold && volOk && distOk) {
            rawSignal = TradeSignal.strongBuy;
          }
        }
        break;
      case 'orb':
        rawSignal = TradeSignal.neutral;
        if (orbRangeComplete && !isNewDay) {
          if (candle.close > dayRangeHigh && candle.high >= dayRangeHigh * 1.001) {
            if (i < adx.length && adx[i] >= adxThreshold && candle.close > vwap) {
              // Phase 2: 거래량 급증 필터 (평균 1.3배)
              final volOk = i < rollingAvgVol.length
                  ? candle.volume >= rollingAvgVol[i] * 1.3
                  : true;
              // Phase 3: CI < 38 (강한 추세장)
              final ciOk = i < ci.length ? ci[i] < 38.2 : true;
              if (volOk && ciOk) {
                rawSignal = TradeSignal.strongBuy;
              }
            }
          }
        }
        break;
      case 'ema_trend':
        rawSignal = TradeSignal.neutral;
        if (i >= emaSlowPeriod && i < emaFast.length && i < emaSlow.length && i < adx.length) {
          if (adx[i] >= adxThreshold) {
            final crossUp = emaFast[i] > emaSlow[i] && emaFast[i - 1] <= emaSlow[i - 1];
            final crossDown = emaFast[i] < emaSlow[i] && emaFast[i - 1] >= emaSlow[i - 1];
            if (crossUp) rawSignal = TradeSignal.strongBuy;
            else if (crossDown) rawSignal = TradeSignal.strongSell;
          }
        }
        break;
      case 'vwap_poc':
        rawSignal = _vwapPocSignal(currentPrice: candle.close, vwap: vwap, poc: poc);
        break;
      default: // vwap_cross
        rawSignal = _vwapCrossSignal(currentPrice: candle.close, vwap: vwap);
    }

    if (rawSignal == TradeSignal.neutral) continue;

    // Long Only: Short 신호 무시
    if (longOnly && rawSignal == TradeSignal.strongSell) continue;

    // 진입 임계값: VWAP과 N틱 이상 떨어져야 진입 (scalp/orb/ema는 자체 조건)
    if (mode != 'vwap_scalp' && mode != 'orb' && mode != 'ema_trend' && entryThresholdTicks > 0) {
      final dist = (candle.close - vwap).abs();
      if (dist < entryThresholdTicks * tickSize) continue;
    }

    // RSI 필터 (scalp/orb/ema는 자체 조건으로 확인)
    if (mode != 'vwap_scalp' && mode != 'orb' && mode != 'ema_trend' && (useRsiFilter || adaptiveMode) && i < rsi.length) {
      final rsiVal = rsi[i];
      if (rawSignal == TradeSignal.strongBuy && rsiVal > ob) continue;
      if (rawSignal == TradeSignal.strongSell && rsiVal < os) continue;
    }

    currentPosition = rawSignal;
    entryPrice = candle.close;
    entryTime = candle.timestamp;
    entryPositionSize = useAtrPositionSizing && i < atr.length && atr[i] > 0 && principal > 0
        ? max(1, (principal * 0.03 / (atr[i] * atrMultiplier)).floor())
        : max(1, (principal / candle.close).floor());
  }

  // 마지막 포지션 청산
  if (currentPosition != null && entryPrice != null && entryTime != null) {
    final last = candles.last;
    final pos = entryPositionSize > 0 ? entryPositionSize : max(1, (principal / entryPrice!).floor());
    final rawPnl = _calculatePnl(
      signal: currentPosition!,
      entryPrice: entryPrice!,
      exitPrice: last.close,
    ) * pos;
    final commission = (entryPrice! + last.close) * pos * (commissionPercent / 100);
    totalCommission += commission;
    dailyPnl += rawPnl - commission;
    trades.add(TradeRecord(
      entryTime: entryTime!,
      exitTime: last.timestamp,
      entryPrice: entryPrice!,
      exitPrice: last.close,
      signal: currentPosition!,
      pnl: rawPnl - commission,
      commission: commission,
    ));
  }

  final totalReturn = trades.fold(0.0, (s, t) => s + t.pnl);
  final wins = trades.where((t) => t.pnl > 0).length;
  final winRate = trades.isEmpty ? 0.0 : wins / trades.length;

  final equityCurve = <double>[];
  double peak = 0;
  double maxDrawdown = 0;
  double runningPnl = 0;
  for (final t in trades) {
    runningPnl += t.pnl;
    equityCurve.add(runningPnl);
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
    principal: principal,
    equityCurve: equityCurve,
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
