import 'trade_record.dart';

class BacktestResult {
  const BacktestResult({
    required this.trades,
    required this.totalReturn,
    required this.totalCommission,
    required this.netReturn,
    required this.winRate,
    required this.totalSignals,
    required this.maxDrawdown,
    required this.sharpeRatio,
    this.principal = 0,
  });

  final List<TradeRecord> trades;

  /// 순손익 (수수료 차감 전)
  final double totalReturn;

  /// 총 수수료
  final double totalCommission;

  /// 순손익 (수수료 차감 후 = totalReturn - totalCommission)
  final double netReturn;

  /// 승률 (0.0 ~ 1.0)
  final double winRate;

  /// 총 신호 발생 횟수 (= 거래 횟수)
  final int totalSignals;

  /// 최대 낙폭 (Max Drawdown)
  final double maxDrawdown;

  /// 샤프 비율
  final double sharpeRatio;

  /// 투자 원금 (0=1주 모드)
  final double principal;

  /// 수익률 (%)
  double get roi => principal > 0 ? netReturn / principal * 100 : 0;

  bool get hasTrades => trades.isNotEmpty;

  double get avgReturn => trades.isEmpty ? 0 : totalReturn / trades.length;

  int get winCount => trades.where((t) => t.pnl > 0).length;

  int get lossCount => trades.where((t) => t.pnl <= 0).length;
}
