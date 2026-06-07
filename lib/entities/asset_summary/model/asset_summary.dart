class AssetSummary {
  final double presentAmount;
  final double totalAsset;
  final double deposit;
  final double d1Deposit;
  final double d2Deposit;
  final double evaluationAmount;

  const AssetSummary({
    this.presentAmount = 0,
    this.totalAsset = 0,
    this.deposit = 0,
    this.d1Deposit = 0,
    this.d2Deposit = 0,
    this.evaluationAmount = 0,
  });

  factory AssetSummary.fromJson(Map<String, dynamic> j) {
    return AssetSummary(
      presentAmount: _firstOf(j, ['prs_amt']),
      totalAsset: _firstOf(j, ['tot_asst_amt', 'tot_evlu_amt']),
      deposit: _firstOf(j, ['dnca_tot_amt', 'dnst_tot_amt']),
      d1Deposit: _firstOf(j, ['nxdy_exc_amt']),
      d2Deposit: _firstOf(j, ['prvs_rcdl_exc_amt']),
      evaluationAmount: _firstOf(j, ['evlu_amt']),
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
