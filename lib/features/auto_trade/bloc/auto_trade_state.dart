import 'package:equatable/equatable.dart';
import '../model/dto/auto_trade_item.dart';

class AutoTradeState extends Equatable {
  final List<AutoTradeItem> items;
  final bool isPaper;
  final double availableBalance;
  final bool isBatchRunning;
  final bool isInitialized;

  const AutoTradeState({
    this.items = const [],
    this.isPaper = true,
    this.availableBalance = 0,
    this.isBatchRunning = false,
    this.isInitialized = false,
  });

  int get totalAllocated =>
      items.fold(0, (sum, item) => sum + item.allocatedAmount);

  int get runningCount =>
      items.where((i) => i.status == TradeStatus.running).length;

  AutoTradeState copyWith({
    List<AutoTradeItem>? items,
    bool? isPaper,
    double? availableBalance,
    bool? isBatchRunning,
    bool? isInitialized,
  }) => AutoTradeState(
    items: items ?? this.items,
    isPaper: isPaper ?? this.isPaper,
    availableBalance: availableBalance ?? this.availableBalance,
    isBatchRunning: isBatchRunning ?? this.isBatchRunning,
    isInitialized: isInitialized ?? this.isInitialized,
  );

  @override
  List<Object?> get props => [items, isPaper, availableBalance, isBatchRunning, isInitialized];
}
