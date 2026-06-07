class TradingPosition {
  const TradingPosition({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.avgPrice,
    required this.currentPrice,
    required this.evaluationAmount,
    required this.profitLoss,
    required this.profitRate,
    required this.purchaseAmount,
  });

  final String symbol;
  final String name;
  final int quantity;
  final double avgPrice;
  final double currentPrice;
  final double evaluationAmount;
  final double profitLoss;
  final double profitRate;
  final double purchaseAmount;

  bool get isProfitable => profitLoss > 0;
}
