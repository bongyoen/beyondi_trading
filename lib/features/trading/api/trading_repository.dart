import 'package:beyondi_trading/entities/order_record/model/order_record.dart';
import 'package:beyondi_trading/entities/trading_position/model/trading_position.dart';

abstract class TradingRepository {
  Future<Map<String, dynamic>> placeBuyOrder({
    required String accountNo,
    required String productCode,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  });

  Future<Map<String, dynamic>> placeSellOrder({
    required String accountNo,
    required String productCode,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  });

  Future<Map<String, dynamic>> cancelOrder({
    required String accountNo,
    required String productCode,
    required String orgOrderNo,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  });

  Future<List<OrderRecord>> fetchDailyOrders({
    required String accountNo,
    required String productCode,
    required String startDate,
    required String endDate,
  });

  Future<List<TradingPosition>> fetchPositions({
    required String accountNo,
    required String productCode,
  });
}
