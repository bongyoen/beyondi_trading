class PeriodProfitLoss {
  final double profitLossAmount;
  final double profitLossRate;
  final double totalBuyAmount;
  final double totalSellAmount;

  const PeriodProfitLoss({
    this.profitLossAmount = 0,
    this.profitLossRate = 0,
    this.totalBuyAmount = 0,
    this.totalSellAmount = 0,
  });

  factory PeriodProfitLoss.fromJson(Map<String, dynamic> j) {
    return PeriodProfitLoss(
      profitLossAmount: _firstOf(j, ['pfls_amt', 'evlu_pfls_amt']),
      profitLossRate: _firstOf(j, ['pfls_erng_rt', 'evlu_erng_rt']),
      totalBuyAmount: _firstOf(j, ['total_buy_amt', 'pchs_amt']),
      totalSellAmount: _firstOf(j, ['total_sll_amt', 'sll_amt']),
    );
  }

  static double _firstOf(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final parsed = double.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}
