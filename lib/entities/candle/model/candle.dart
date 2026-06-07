/// OHLCV 캔들 데이터.
///
/// 경계(boundary)에서 파싱된 후 내부에서는 항상 유효한 값이 보장됨.
class Candle {
  const Candle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  /// 중간가 (Typical Price): (고가 + 저가 + 종가) / 3
  double get typicalPrice => (high + low + close) / 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Candle &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          open == other.open &&
          high == other.high &&
          low == other.low &&
          close == other.close &&
          volume == other.volume;

  @override
  int get hashCode => Object.hash(timestamp, open, high, low, close, volume);

  @override
  String toString() =>
      'Candle(${timestamp.toIso8601String()}, O:$open H:$high L:$low C:$close V:$volume)';
}
