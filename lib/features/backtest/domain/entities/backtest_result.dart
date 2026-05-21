import 'trade_record.dart';

/// 백테스트 수행 결과.
class BacktestResult {
  const BacktestResult({
    required this.trades,
    required this.totalReturn,
    required this.winRate,
    required this.totalSignals,
    required this.maxDrawdown,
    required this.sharpeRatio,
  });

  /// 전체 체결된 거래 목록
  final List<TradeRecord> trades;

  /// 총 손익
  final double totalReturn;

  /// 승률 (0.0 ~ 1.0)
  final double winRate;

  /// 총 신호 발생 횟수 (= 거래 횟수)
  final int totalSignals;

  /// 최대 낙폭 (Max Drawdown)
  final double maxDrawdown;

  /// 샤프 비율 (단순화: 평균수익률 / 표준편차)
  final double sharpeRatio;

  /// 거래가 하나라도 있었는지 여부
  bool get hasTrades => trades.isNotEmpty;

  /// 평균 손익
  double get avgReturn => trades.isEmpty ? 0 : totalReturn / trades.length;

  /// 승리 거래 수
  int get winCount => trades.where((t) => t.pnl > 0).length;

  /// 패배 거래 수
  int get lossCount => trades.where((t) => t.pnl <= 0).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BacktestResult &&
          runtimeType == other.runtimeType &&
          totalReturn == other.totalReturn &&
          winRate == other.winRate &&
          totalSignals == other.totalSignals &&
          maxDrawdown == other.maxDrawdown &&
          sharpeRatio == other.sharpeRatio;

  @override
  int get hashCode =>
      Object.hash(totalReturn, winRate, totalSignals, maxDrawdown, sharpeRatio);

  @override
  String toString() =>
      'BacktestResult(trades:$totalSignals, return:$totalReturn, '
      'winRate:${(winRate * 100).toStringAsFixed(1)}%, '
      'maxDD:${maxDrawdown.toStringAsFixed(2)}, '
      'sharpe:${sharpeRatio.toStringAsFixed(2)})';
}
