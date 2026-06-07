import 'dart:math';

import 'package:beyondi_trading/entities/candle/model/candle.dart';

/// RSI(14) 계산. Wilder's smoothing 사용.
List<double> calculateRsi(List<Candle> candles, {int period = 14}) {
  if (candles.length < period + 1) {
    return List.filled(candles.length, 50);
  }

  final changes = <double>[];
  for (int i = 1; i < candles.length; i++) {
    changes.add(candles[i].close - candles[i - 1].close);
  }

  final rsi = List.filled(candles.length, 50.0);

  double avgGain = 0;
  double avgLoss = 0;
  for (int i = 0; i < period; i++) {
    if (changes[i] > 0) {
      avgGain += changes[i];
    } else {
      avgLoss -= changes[i];
    }
  }
  avgGain /= period;
  avgLoss /= period;

  rsi[period] = _computeRsi(avgGain, avgLoss);

  for (int i = period + 1; i < candles.length; i++) {
    final gain = changes[i - 1] > 0 ? changes[i - 1] : 0;
    final loss = changes[i - 1] < 0 ? -changes[i - 1] : 0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    rsi[i] = _computeRsi(avgGain, avgLoss);
  }

  return rsi;
}

double _computeRsi(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100;
  if (avgGain == 0) return 0;
  final rs = avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}

/// ATR(14) 계산.
List<double> calculateAtr(List<Candle> candles, {int period = 14}) {
  if (candles.length < 2) {
    return List.filled(candles.length, 0);
  }

  final tr = <double>[];
  tr.add(candles[0].high - candles[0].low);
  for (int i = 1; i < candles.length; i++) {
    final hl = candles[i].high - candles[i].low;
    final hc = (candles[i].high - candles[i - 1].close).abs();
    final lc = (candles[i].low - candles[i - 1].close).abs();
    tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
  }

  final atr = List.filled(candles.length, 0.0);

  double sum = 0;
  for (int i = 0; i < period; i++) {
    sum += tr[i];
  }
  atr[period - 1] = sum / period;

  for (int i = period; i < candles.length; i++) {
    atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period;
  }

  return atr;
}

/// Choppiness Index (CI) — 시장이 횡보/추세 중인지 판단.
/// CI > 61.8 = 횡보장, CI < 38.2 = 추세장.
/// [period] 계산 기간 (기본 14).
List<double> calculateChoppinessIndex(List<Candle> candles, {int period = 14}) {
  if (candles.length < period + 1) {
    return List.filled(candles.length, 50);
  }

  // True Range
  final tr = <double>[];
  tr.add(candles[0].high - candles[0].low);
  for (int i = 1; i < candles.length; i++) {
    final hl = candles[i].high - candles[i].low;
    final hc = (candles[i].high - candles[i - 1].close).abs();
    final lc = (candles[i].low - candles[i - 1].close).abs();
    tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
  }

  final ci = List.filled(candles.length, 50.0);

  for (int i = period; i < candles.length; i++) {
    double sumTr = 0;
    double maxHigh = candles[i].high;
    double minLow = candles[i].low;
    for (int j = i - period + 1; j <= i; j++) {
      sumTr += tr[j];
      if (candles[j].high > maxHigh) maxHigh = candles[j].high;
      if (candles[j].low < minLow) minLow = candles[j].low;
    }
    final range = maxHigh - minLow;
    if (range > 0 && sumTr > 0) {
      ci[i] = 100 * log(sumTr / range) / log(period);
    }
  }

  return ci;
}

/// ATR 기반 RSI 임계값 계산.
/// 변동성 높으면 → 과매수/과매도 기준 확장 (신호 필터링 강화)
/// [rsiBase] 기본 RSI 값 (과매수=70, 과매도=30)
/// [atrRatio] 현재 ATR / 평균 ATR 비율
(double overbought, double oversold) adaptiveRsiLevels({
  double atrRatio = 1.0,
  double rsiBase = 70,
}) {
  // atrRatio=1.0 → ±0 (70/30)
  // atrRatio=1.5 → ±5 (75/25)
  // atrRatio=0.5 → ±5 (65/35)
  final offset = ((atrRatio - 1) * 10).clamp(-10, 10);
  return (rsiBase + offset, 100 - rsiBase - offset);
}

/// EMA 계산.
List<double> calculateEma(List<double> values, int period) {
  final ema = List.filled(values.length, 0.0);
  if (values.isEmpty) return ema;
  double sum = 0;
  for (int i = 0; i < period && i < values.length; i++) sum += values[i];
  ema[period - 1] = sum / period;
  final multiplier = 2 / (period + 1);
  for (int i = period; i < values.length; i++) {
    ema[i] = (values[i] - ema[i - 1]) * multiplier + ema[i - 1];
  }
  return ema;
}

/// MACD(12,26,9) 계산. returns (macdLine, signalLine, histogram)
(List<double>, List<double>, List<double>) calculateMacd(List<Candle> candles) {
  final closes = candles.map((c) => c.close).toList();
  final ema12 = calculateEma(closes, 12);
  final ema26 = calculateEma(closes, 26);
  final macd = List.generate(closes.length, (i) => ema12[i] - ema26[i]);
  final signal = calculateEma(macd, 9);
  final hist = List.generate(closes.length, (i) => macd[i] - signal[i]);
  return (macd, signal, hist);
}

/// MACD 신호: 0=neutral, 1=buy, 2=sell
List<int> calculateMacdSignal(List<Candle> candles) {
  final (macd, signal, _) = calculateMacd(candles);
  final result = List.filled(candles.length, 0);
  for (int i = 1; i < candles.length; i++) {
    if (macd[i] > signal[i] && macd[i - 1] <= signal[i - 1]) result[i] = 1; // 골든크로스
    else if (macd[i] < signal[i] && macd[i - 1] >= signal[i - 1]) result[i] = 2; // 데드크로스
  }
  return result;
}

/// ADX(14) 계산.
/// [period] 기본 14
List<double> calculateAdx(List<Candle> candles, {int period = 14}) {
  final result = List.filled(candles.length, 0.0);
  if (candles.length < period + 1) return result;

  // True Range
  final tr = <double>[];
  tr.add(candles[0].high - candles[0].low);
  for (int i = 1; i < candles.length; i++) {
    final hl = candles[i].high - candles[i].low;
    final hc = (candles[i].high - candles[i - 1].close).abs();
    final lc = (candles[i].low - candles[i - 1].close).abs();
    tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
  }

  // Directional Movement
  final plusDm = <double>[];
  final minusDm = <double>[];
  plusDm.add(0); minusDm.add(0);
  for (int i = 1; i < candles.length; i++) {
    final up = candles[i].high - candles[i - 1].high;
    final down = candles[i - 1].low - candles[i].low;
    plusDm.add(up > down && up > 0 ? up : 0);
    minusDm.add(down > up && down > 0 ? down : 0);
  }

  double trSum = 0, pSum = 0, mSum = 0;
  for (int i = 0; i < period; i++) {
    trSum += tr[i]; pSum += plusDm[i]; mSum += minusDm[i];
  }

  for (int i = period; i < candles.length; i++) {
    trSum = trSum - trSum / period.toDouble() + tr[i];
    pSum = pSum - pSum / period.toDouble() + plusDm[i];
    mSum = mSum - mSum / period.toDouble() + minusDm[i];
    final pDi = trSum > 0 ? 100.0 * pSum / trSum : 0.0;
    final mDi = trSum > 0 ? 100.0 * mSum / trSum : 0.0;
    final dx = (pDi + mDi) > 0 ? 100 * (pDi - mDi).abs() / (pDi + mDi) : 0.0;
    result[i] = result[i - 1] > 0
        ? (result[i - 1] * (period - 1) + dx) / period.toDouble()
        : dx;
  }
  return result;
}

/// OBV (On-Balance Volume) 계산.
List<double> calculateObv(List<Candle> candles) {
  final obv = List.filled(candles.length, 0.0);
  obv[0] = candles[0].volume;
  for (int i = 1; i < candles.length; i++) {
    if (candles[i].close > candles[i - 1].close) {
      obv[i] = obv[i - 1] + candles[i].volume;
    } else if (candles[i].close < candles[i - 1].close) {
      obv[i] = obv[i - 1] - candles[i].volume;
    } else {
      obv[i] = obv[i - 1];
    }
  }
  return obv;
}

/// OBV 다이버전스 신호: 0=없음, 1=buy, 2=sell
/// [lookback] 확인할 기간 (기본 20)
List<int> calculateObvDivergence(List<Candle> candles, {int lookback = 20}) {
  final obv = calculateObv(candles);
  final result = List.filled(candles.length, 0);
  if (candles.length < lookback + 1) return result;

  for (int i = lookback; i < candles.length; i++) {
    final slice = i - lookback;
    final priceMax = candles[slice].high;
    final priceMin = candles[slice].low;
    double maxHighPrice = priceMax, maxHighObv = obv[slice];
    double minLowPrice = priceMin, minLowObv = obv[slice];
    int maxIdx = slice, minIdx = slice;

    for (int j = slice; j <= i; j++) {
      if (candles[j].high > maxHighPrice) {
        maxHighPrice = candles[j].high; maxHighObv = obv[j]; maxIdx = j;
      }
      if (candles[j].low < minLowPrice) {
        minLowPrice = candles[j].low; minLowObv = obv[j]; minIdx = j;
      }
    }

    // Bearish divergence: 가격 신고가 but OBV는 낮은 고점 → Short
    if (maxIdx == i && maxHighObv < obv[maxIdx - lookback ~/ 2]) result[i] = 2;
    // Bullish divergence: 가격 신저가 but OBV는 높은 저점 → Long
    if (minIdx == i && minLowObv > obv[minIdx - lookback ~/ 2]) result[i] = 1;
  }
  return result;
}
