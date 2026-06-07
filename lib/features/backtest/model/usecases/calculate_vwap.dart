import 'package:beyondi_trading/entities/candle/model/candle.dart';
import 'package:beyondi_trading/entities/vwap_result/model/vwap_result.dart';

/// 순수 함수형 VWAP 계산 유스케이스.
///
/// 동일한 입력 → 동일한 출력 (Atomic Predictability).
/// Running VWAP + Running POC(Point of Control)를 동시에 계산.
VwapResult calculateVwap({
  required List<Candle> candles,
  double tickSize = 1.0,
}) {
  if (candles.isEmpty) {
    return const VwapResult(vwapSeries: [], pocSeries: []);
  }

  final vwapSeries = <double>[];
  final pocSeries = <double?>[];
  final volumeProfile = <double, double>{};

  double cumTpv = 0; // Σ(typicalPrice × volume)
  double cumVol = 0; // Σ(volume)

  for (final candle in candles) {
    final tpv = candle.typicalPrice * candle.volume;
    cumTpv += tpv;
    cumVol += candle.volume;

    // Running VWAP
    vwapSeries.add(cumTpv / cumVol);

    // Update volume profile for POC — typical price 기준 버킷
    final level = (candle.typicalPrice / tickSize).round() * tickSize;
    volumeProfile[level] = (volumeProfile[level] ?? 0) + candle.volume;

    // Running POC: 현재까지 가장 많은 거래량이 발생한 가격 수준
    double? poc;
    double maxVol = 0;
    for (final entry in volumeProfile.entries) {
      if (entry.value > maxVol) {
        maxVol = entry.value;
        poc = entry.key;
      }
    }
    pocSeries.add(poc);
  }

  // 전체 기간 최종 POC
  double? overallPoc;
  double overallMaxVol = 0;
  for (final entry in volumeProfile.entries) {
    if (entry.value > overallMaxVol) {
      overallMaxVol = entry.value;
      overallPoc = entry.key;
    }
  }

  return VwapResult(
    vwapSeries: vwapSeries,
    pocSeries: pocSeries,
    overallPoc: overallPoc,
  );
}
