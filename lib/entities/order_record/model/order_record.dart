class OrderRecord {
  const OrderRecord({
    required this.orderNo,
    required this.symbol,
    required this.name,
    required this.side,
    required this.quantity,
    required this.price,
    required this.orderDivision,
    required this.status,
    this.filledQuantity = 0,
    this.filledPrice = 0,
    this.filledAmount = 0,
    this.pendingQuantity = 0,
    this.orderTime,
    this.fillTime,
    this.rejectReason,
    this.commission = 0,
  });

  final String orderNo;
  final String symbol;
  final String name;
  final String side;
  final int quantity;
  final double price;
  final String orderDivision;
  final String status;
  final int filledQuantity;
  final double filledPrice;
  final double filledAmount;
  final int pendingQuantity;
  final DateTime? orderTime;
  final DateTime? fillTime;
  final String? rejectReason;
  final double commission;

  bool get isBuy => side == 'buy';
  bool get isSell => side == 'sell';
  bool get isFilled => status == 'filled';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';

  OrderRecord copyWith({
    String? orderNo,
    String? symbol,
    String? name,
    String? side,
    int? quantity,
    double? price,
    String? orderDivision,
    String? status,
    int? filledQuantity,
    double? filledPrice,
    double? filledAmount,
    int? pendingQuantity,
    DateTime? orderTime,
    DateTime? fillTime,
    String? rejectReason,
    double? commission,
  }) {
    return OrderRecord(
      orderNo: orderNo ?? this.orderNo,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      side: side ?? this.side,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      orderDivision: orderDivision ?? this.orderDivision,
      status: status ?? this.status,
      filledQuantity: filledQuantity ?? this.filledQuantity,
      filledPrice: filledPrice ?? this.filledPrice,
      filledAmount: filledAmount ?? this.filledAmount,
      pendingQuantity: pendingQuantity ?? this.pendingQuantity,
      orderTime: orderTime ?? this.orderTime,
      fillTime: fillTime ?? this.fillTime,
      rejectReason: rejectReason ?? this.rejectReason,
      commission: commission ?? this.commission,
    );
  }
}
