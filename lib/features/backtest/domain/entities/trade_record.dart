import 'trade_signal.dart';

/// 백테스트에서 체결된 개별 거래 내역.
class TradeRecord {
  const TradeRecord({
    required this.entryTime,
    required this.exitTime,
    required this.entryPrice,
    required this.exitPrice,
    required this.signal,
    required this.pnl,
    this.commission = 0,
  });

  /// 진입 시각
  final DateTime entryTime;

  /// 청산 시각
  final DateTime exitTime;

  /// 진입 가격
  final double entryPrice;

  /// 청산 가격
  final double exitPrice;

  /// 진입 당시 신호 방향
  final TradeSignal signal;

  /// 손익 (long: 매도가-매수가, short: 매수가-매도가)
  final double pnl;

  /// 거래 수수료
  final double commission;

  /// 손익률 (%)
  double get pnlPercent =>
      entryPrice == 0 ? 0 : (pnl / entryPrice) * 100;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeRecord &&
          runtimeType == other.runtimeType &&
          entryTime == other.entryTime &&
          exitTime == other.exitTime &&
          entryPrice == other.entryPrice &&
          exitPrice == other.exitPrice &&
          signal == other.signal &&
          pnl == other.pnl &&
          commission == other.commission;

  @override
  int get hashCode =>
      Object.hash(entryTime, exitTime, entryPrice, exitPrice, signal, pnl, commission);

  @override
  String toString() =>
      'Trade(${signal.name}, entry:$entryPrice exit:$exitPrice pnl:$pnl comm:$commission)';
}
