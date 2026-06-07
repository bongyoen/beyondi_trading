import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/entities/order_record/model/order_record.dart';
import 'package:beyondi_trading/entities/trading_position/model/trading_position.dart';
import 'package:beyondi_trading/features/trading/api/trading_repository.dart';

class KisTradingRepository implements TradingRepository {
  KisTradingRepository({required KisStockApi api}) : _api = api;

  final KisStockApi _api;

  @override
  Future<Map<String, dynamic>> placeBuyOrder({
    required String accountNo,
    required String productCode,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  }) async {
    return _api.orderBuy(
      accountNo: accountNo,
      productCode: productCode,
      symbol: symbol,
      quantity: quantity,
      price: price,
      orderDivision: orderDivision,
    );
  }

  @override
  Future<Map<String, dynamic>> placeSellOrder({
    required String accountNo,
    required String productCode,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  }) async {
    return _api.orderSell(
      accountNo: accountNo,
      productCode: productCode,
      symbol: symbol,
      quantity: quantity,
      price: price,
      orderDivision: orderDivision,
    );
  }

  @override
  Future<Map<String, dynamic>> cancelOrder({
    required String accountNo,
    required String productCode,
    required String orgOrderNo,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  }) async {
    return _api.cancelOrder(
      accountNo: accountNo,
      productCode: productCode,
      orgOrderNo: orgOrderNo,
      symbol: symbol,
      quantity: quantity,
      price: price,
      orderDivision: orderDivision,
    );
  }

  @override
  Future<List<OrderRecord>> fetchDailyOrders({
    required String accountNo,
    required String productCode,
    required String startDate,
    required String endDate,
  }) async {
    final rawList = await _api.fetchDailyOrderDetail(
      accountNo: accountNo,
      productCode: productCode,
      startDate: startDate,
      endDate: endDate,
    );
    return rawList.map((e) => _parseOrder(e)).toList();
  }

  @override
  Future<List<TradingPosition>> fetchPositions({
    required String accountNo,
    required String productCode,
  }) async {
    final (holdings, _) = await _api.fetchBalance(
      accountNo: accountNo,
      productCode: productCode,
    );
    return holdings.map((e) => _parsePosition(e)).toList();
  }

  OrderRecord _parseOrder(Map<String, dynamic> json) {
    final qty = _int(json['ord_qty']);
    final filled = _int(json['ccld_qty']);
    final pending = qty - filled;
    return OrderRecord(
      orderNo: json['odno'] as String? ?? '',
      symbol: json['pdno'] as String? ?? '',
      name: json['prdt_name'] as String? ?? '',
      side: (json['sll_buy_dvsn_cd'] as String? ?? '') == '01' ? 'sell' : 'buy',
      quantity: qty,
      price: _double(json['ord_unpr']),
      orderDivision: json['ord_dvsn_cd'] as String? ?? '00',
      status: filled >= qty ? 'filled' : (filled > 0 ? 'partial' : 'pending'),
      filledQuantity: filled,
      filledPrice: _double(json['ccld_unpr']),
      filledAmount: _double(json['tot_ccld_amt']),
      pendingQuantity: pending > 0 ? pending : 0,
      orderTime: _tryParseDateTime(json['ord_tmd'] as String?),
      commission: _double(json['cmsn_amt']),
    );
  }

  TradingPosition _parsePosition(Map<String, dynamic> json) {
    return TradingPosition(
      symbol: json['pdno'] as String? ?? '',
      name: json['prdt_name'] as String? ?? json['prdt_abrv_name'] as String? ?? '',
      quantity: _int(json['hldg_qty']),
      avgPrice: _double(json['pchs_avg_pric']),
      currentPrice: _double(json['prpr']),
      evaluationAmount: _double(json['evlu_amt']),
      profitLoss: _double(json['evlu_pfls_amt']),
      profitRate: _double(json['evlu_erng_rt']),
      purchaseAmount: _double(json['pchs_amt']),
    );
  }

  DateTime? _tryParseDateTime(String? s) {
    if (s == null || s.length < 6) return null;
    final now = DateTime.now();
    return DateTime(
      now.year, now.month, now.day,
      int.parse(s.substring(0, 2)),
      int.parse(s.substring(2, 4)),
      int.parse(s.substring(4, 6)),
    );
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  double _double(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
