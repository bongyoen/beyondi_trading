import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/backtest_result.dart';
import '../../domain/entities/candle.dart';
import '../../domain/entities/trade_record.dart';
import '../../domain/entities/trade_signal.dart';

/// 캔들 데이터 + 백테스트 결과 로컬 JSON 파일 캐시.
///
/// - 캔들: `candle_{symbol}_{start}{end}_1d.json`
/// - 결과: `result_{symbol}_{tickSize}.json`
class CandleCache {
  CandleCache._();

  static final CandleCache _instance = CandleCache._();
  factory CandleCache() => _instance;

  Directory? _cacheDir;

  Future<Directory> _getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    _cacheDir = await getApplicationSupportDirectory();
    return _cacheDir!;
  }

  String _fileName({
    required String symbol,
    required DateTime start,
    required DateTime end,
    String interval = '1d',
  }) {
    final s = _fmt(start);
    final e = _fmt(end);
    return 'candle_${symbol}_$s${e}_$interval.json';
  }

  String _fmt(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// 캐시된 캔들 데이터 로드.
  Future<List<Candle>?> load({
    required String symbol,
    required DateTime start,
    required DateTime end,
    String interval = '1d',
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_fileName(symbol: symbol, start: start, end: end, interval: interval)}');
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _candleFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  /// 캔들 데이터 캐시에 저장.
  Future<void> save({
    required String symbol,
    required DateTime start,
    required DateTime end,
    required List<Candle> candles,
    String interval = '1d',
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_fileName(symbol: symbol, start: start, end: end, interval: interval)}');
      final list = candles.map((c) => _candleToJson(c)).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  Map<String, dynamic> _candleToJson(Candle c) => {
        't': c.timestamp.toIso8601String(),
        'o': c.open,
        'h': c.high,
        'l': c.low,
        'c': c.close,
        'v': c.volume,
      };

  Candle _candleFromJson(Map<String, dynamic> m) => Candle(
        timestamp: DateTime.parse(m['t'] as String),
        open: (m['o'] as num).toDouble(),
        high: (m['h'] as num).toDouble(),
        low: (m['l'] as num).toDouble(),
        close: (m['c'] as num).toDouble(),
        volume: (m['v'] as num).toDouble(),
      );

  // ── BacktestResult ──────────────────────────────────────────────

  String _resultFile({
    required String symbol,
    required double tickSize,
  }) =>
      'result_${symbol}_${tickSize.toStringAsFixed(0)}.json';

  /// 저장된 백테스트 결과 로드.
  Future<BacktestResult?> loadResult({
    required String symbol,
    required double tickSize,
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_resultFile(symbol: symbol, tickSize: tickSize)}');
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return _resultFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 백테스트 결과 저장.
  Future<void> saveResult({
    required String symbol,
    required double tickSize,
    required BacktestResult result,
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_resultFile(symbol: symbol, tickSize: tickSize)}');
      await file.writeAsString(jsonEncode(_resultToJson(result)));
    } catch (_) {}
  }

  Map<String, dynamic> _resultToJson(BacktestResult r) => {
        'totalReturn': r.totalReturn,
        'totalCommission': r.totalCommission,
        'netReturn': r.netReturn,
        'winRate': r.winRate,
        'totalSignals': r.totalSignals,
        'maxDrawdown': r.maxDrawdown,
        'sharpeRatio': r.sharpeRatio,
        'trades': r.trades.map(_tradeToJson).toList(),
      };

  BacktestResult _resultFromJson(Map<String, dynamic> m) => BacktestResult(
        totalReturn: (m['totalReturn'] as num).toDouble(),
        totalCommission: (m['totalCommission'] as num?)?.toDouble() ?? 0,
        netReturn: (m['netReturn'] as num?)?.toDouble() ?? (m['totalReturn'] as num).toDouble(),
        winRate: (m['winRate'] as num).toDouble(),
        totalSignals: m['totalSignals'] as int,
        maxDrawdown: (m['maxDrawdown'] as num).toDouble(),
        sharpeRatio: (m['sharpeRatio'] as num).toDouble(),
        trades: (m['trades'] as List<dynamic>)
            .map((e) => _tradeFromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> _tradeToJson(TradeRecord t) => {
        'entryTime': t.entryTime.toIso8601String(),
        'exitTime': t.exitTime.toIso8601String(),
        'entryPrice': t.entryPrice,
        'exitPrice': t.exitPrice,
        'signal': t.signal.name,
        'pnl': t.pnl,
      };

  TradeRecord _tradeFromJson(Map<String, dynamic> m) => TradeRecord(
        entryTime: DateTime.parse(m['entryTime'] as String),
        exitTime: DateTime.parse(m['exitTime'] as String),
        entryPrice: (m['entryPrice'] as num).toDouble(),
        exitPrice: (m['exitPrice'] as num).toDouble(),
        signal: m['signal'] == 'strongBuy' ? TradeSignal.strongBuy : TradeSignal.strongSell,
        pnl: (m['pnl'] as num).toDouble(),
      );

  /// 캔들 + 결과 파일 삭제.
  Future<void> delete({
    required String symbol,
    required DateTime start,
    required DateTime end,
    required double tickSize,
    String interval = '1d',
  }) async {
    try {
      final dir = await _getDir();
      final cf = File('${dir.path}/${_fileName(symbol: symbol, start: start, end: end, interval: interval)}');
      if (await cf.exists()) await cf.delete();
      final rf = File('${dir.path}/${_resultFile(symbol: symbol, tickSize: tickSize)}');
      if (await rf.exists()) await rf.delete();
    } catch (_) {}
  }
}
