import 'package:beyondi_trading/entities/candle/model/candle.dart';

/// 백테스트 데이터 소스에 대한 경계 계약.
///
/// 도메인 계층은 이 추상화에만 의존하며,
/// 구체 구현체(로컬 CSV, API, DB 등)는 data 레이어에서 담당.
abstract class BacktestRepository {
  /// 주어진 심볼과 기간의 캔들 데이터를 불러옵니다.
  ///
  /// [symbol] 종목 식별자 (예: 'AAPL', 'BTCUSDT')
  /// [start] 조회 시작일 (포함)
  /// [end]   조회 종료일 (포함)
  /// [interval] 캔들 간격 (예: '1d', '1h', '5m')
  Future<List<Candle>> loadCandles({
    required String symbol,
    required DateTime start,
    required DateTime end,
    String interval = '1d',
  });
}
