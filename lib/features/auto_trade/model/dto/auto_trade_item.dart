enum TradeStatus { ready, running, paused, sold }

class AutoTradeItem {
  final String code;
  final String name;
  final int allocatedAmount;
  final TradeStatus status;
  final double? entryPrice;
  final int? quantity;
  final double? currentPrice;
  final String? orderNo;

  const AutoTradeItem({
    required this.code,
    required this.name,
    this.allocatedAmount = 0,
    this.status = TradeStatus.ready,
    this.entryPrice,
    this.quantity,
    this.currentPrice,
    this.orderNo,
  });

  double get profitLoss {
    if (entryPrice == null || currentPrice == null || quantity == null) return 0;
    return (currentPrice! - entryPrice!) * quantity!;
  }

  double get profitRate {
    if (entryPrice == null || entryPrice == 0) return 0;
    return (currentPrice! - entryPrice!) / entryPrice! * 100;
  }

  AutoTradeItem copyWith({
    int? allocatedAmount,
    TradeStatus? status,
    double? entryPrice,
    int? quantity,
    double? currentPrice,
    String? orderNo,
  }) => AutoTradeItem(
    code: code,
    name: name,
    allocatedAmount: allocatedAmount ?? this.allocatedAmount,
    status: status ?? this.status,
    entryPrice: entryPrice ?? this.entryPrice,
    quantity: quantity ?? this.quantity,
    currentPrice: currentPrice ?? this.currentPrice,
    orderNo: orderNo ?? this.orderNo,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'allocatedAmount': allocatedAmount,
  };

  factory AutoTradeItem.fromJson(Map<String, dynamic> json) => AutoTradeItem(
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    allocatedAmount: (json['allocatedAmount'] as num?)?.toInt() ?? 0,
  );
}
