class VwapPocItem {
  final String code;
  final String name;
  final int score;
  final double ci;
  final double vwapDist;
  final double vwapSlope;
  final double periodReturn;
  final double atrRatio;
  final double close;
  final double vwap;

  const VwapPocItem({
    required this.code,
    required this.name,
    required this.score,
    required this.ci,
    required this.vwapDist,
    required this.vwapSlope,
    required this.periodReturn,
    required this.atrRatio,
    required this.close,
    required this.vwap,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'score': score,
    'ci': ci,
    'vwapDist': vwapDist,
    'vwapSlope': vwapSlope,
    'periodReturn': periodReturn,
    'atrRatio': atrRatio,
    'close': close,
    'vwap': vwap,
  };

  factory VwapPocItem.fromJson(Map<String, dynamic> json) => VwapPocItem(
    code: (json['code'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    score: (json['score'] as num?)?.toInt() ?? 0,
    ci: (json['ci'] as num?)?.toDouble() ?? 0,
    vwapDist: (json['vwapDist'] as num?)?.toDouble() ?? 0,
    vwapSlope: (json['vwapSlope'] as num?)?.toDouble() ?? 0,
    periodReturn: (json['periodReturn'] as num?)?.toDouble() ?? 0,
    atrRatio: (json['atrRatio'] as num?)?.toDouble() ?? 0,
    close: (json['close'] as num?)?.toDouble() ?? 0,
    vwap: (json['vwap'] as num?)?.toDouble() ?? 0,
  );

  @override
  String toString() => 'VwapPocItem($code $name score=$score)';
}
