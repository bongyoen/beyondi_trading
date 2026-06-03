class BuyPower {
  final double maxOrderAmount;
  final int maxOrderQuantity;
  final double maxSellAmount;

  const BuyPower({
    this.maxOrderAmount = 0,
    this.maxOrderQuantity = 0,
    this.maxSellAmount = 0,
  });

  factory BuyPower.fromJson(Map<String, dynamic> j) {
    return BuyPower(
      maxOrderAmount: _firstOf(j, ['max_ord_psbl_amt', 'ord_psbl_amt']),
      maxOrderQuantity: int.tryParse(j['max_ord_psbl_qty']?.toString() ?? '0') ?? 0,
      maxSellAmount: _firstOf(j, ['max_ord_psbl_amt_by_sell', 'sll_psbl_amt']),
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
