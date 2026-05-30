import '../../domain/entities/candle.dart';
import '../../domain/entities/backtest_result.dart';
import '../../domain/usecases/run_backtest.dart';
import '../datasources/kis_stock_api.dart';
import 'backtest_repository.dart';

/// KIS Open API 기반 백테스트 저장소 구현체.
///
/// [KisStockApi]를 통해 실제 시세 데이터를 조회하고
/// VWAP+POC 전략 백테스트를 실행한다.
class KisBacktestRepository implements BacktestRepository {
  KisBacktestRepository({required KisStockApi kisApi}) : _kisApi = kisApi;

  final KisStockApi _kisApi;

  @override
  Future<List<Candle>> loadCandles({
    required String symbol,
    required DateTime start,
    required DateTime end,
    String interval = '1d',
  }) async {
    if (interval != '1d') {
      throw UnsupportedError(
        'KIS API는 현재 일봉(1d)만 지원합니다. 요청: $interval',
      );
    }

    return _kisApi.fetchDailyCandles(
      symbol: symbol,
      start: start,
      end: end,
    );
  }

  /// 캔들 데이터를 조회하고 바로 백테스트 실행.
  Future<BacktestResult> run({
    required String symbol,
    required DateTime start,
    required DateTime end,
    double tickSize = 1.0,
  }) async {
    final candles = await loadCandles(
      symbol: symbol,
      start: start,
      end: end,
    );

    return runBacktest(candles: candles, tickSize: tickSize);
  }
}
