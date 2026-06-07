class AccountBalance {
  final double totalAsset;
  final double stockEvaluation;
  final double evaluationProfitLoss;
  final double evaluationProfitRate;
  final double deposit;
  final double d1Deposit;
  final double d2Deposit;
  final double purchaseAmount;
  final double evaluationAmount;
  final List<StockHolding> holdings;

  const AccountBalance({
    this.totalAsset = 0,
    this.stockEvaluation = 0,
    this.evaluationProfitLoss = 0,
    this.evaluationProfitRate = 0,
    this.deposit = 0,
    this.d1Deposit = 0,
    this.d2Deposit = 0,
    this.purchaseAmount = 0,
    this.evaluationAmount = 0,
    this.holdings = const [],
  });

  factory AccountBalance.fromJson(Map<String, dynamic> json) {
    return AccountBalance(
      totalAsset: _parseDouble(json['tota_assamt']),
      stockEvaluation: _parseDouble(json['scts_evlu_amt']),
      evaluationProfitLoss: _parseDouble(json['evlu_pfls_smtl_amt']),
      evaluationProfitRate: _parseDouble(json['evlu_tota_erng_rt']),
      deposit: _parseDouble(json['dnca_tot_amt']),
      d1Deposit: _parseDouble(json['nxdy_exc_amt']),
      d2Deposit: _parseDouble(json['prvs_rcdl_exc_amt']),
      purchaseAmount: _parseDouble(json['pchs_amt_smtl_amt']),
      evaluationAmount: _parseDouble(json['evlu_amt_smtl_amt']),
    );
  }

  static double _parseDouble(dynamic v) =>
      v == null ? 0 : (double.tryParse(v.toString()) ?? 0);
}

class StockHolding {
  final String symbol;
  final String name;
  final int quantity;
  final double avgPrice;
  final double currentPrice;
  final double evaluationAmount;
  final double profitLoss;
  final double profitRate;

  const StockHolding({
    this.symbol = '',
    this.name = '',
    this.quantity = 0,
    this.avgPrice = 0,
    this.currentPrice = 0,
    this.evaluationAmount = 0,
    this.profitLoss = 0,
    this.profitRate = 0,
  });

  factory StockHolding.fromJson(Map<String, dynamic> json) {
    return StockHolding(
      symbol: (json['pdno'] as String?) ?? '',
      name: (json['prdt_name'] as String?) ?? '',
      quantity: int.tryParse(json['hldg_qty']?.toString() ?? '0') ?? 0,
      avgPrice: _parseDouble(json['pchs_avg_pric']),
      currentPrice: _parseDouble(json['prpr']),
      evaluationAmount: _parseDouble(json['evlu_amt']),
      profitLoss: _parseDouble(json['evlu_pfls_amt']),
      profitRate: _parseDouble(json['evlu_erng_rt']),
    );
  }

  static double _parseDouble(dynamic v) =>
      v == null ? 0 : (double.tryParse(v.toString()) ?? 0);
}
