/// VWAP 계산 결과.
class VwapResult {
  const VwapResult({
    required this.vwapSeries,
    required this.pocSeries,
    this.overallPoc,
  });

  /// 각 캔들별 VWAP 값 리스트 (running VWAP)
  final List<double> vwapSeries;

  /// 각 캔들별 POC 값 리스트 (running POC)
  final List<double?> pocSeries;

  /// 전체 기간의 최종 POC
  final double? overallPoc;

  /// 마지막 캔들의 VWAP
  double? get latestVwap => vwapSeries.isEmpty ? null : vwapSeries.last;

  /// 마지막 캔들의 POC
  double? get latestPoc => pocSeries.isEmpty ? null : pocSeries.last;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VwapResult &&
          runtimeType == other.runtimeType &&
          overallPoc == other.overallPoc;

  @override
  int get hashCode => overallPoc.hashCode;

  @override
  String toString() =>
      'VwapResult(candles:${vwapSeries.length}, latestVwap:$latestVwap, latestPoc:$latestPoc)';
}
