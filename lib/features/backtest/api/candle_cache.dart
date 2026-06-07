import 'dart:convert';
import 'dart:io';

import 'package:beyondi_trading/entities/backtest_result/model/backtest_result.dart';
import 'package:beyondi_trading/entities/candle/model/candle.dart';
import 'package:beyondi_trading/entities/trade_record/model/trade_record.dart';
import 'package:beyondi_trading/entities/trade_signal/model/trade_signal.dart';

/// 캔들 데이터 + 백테스트 결과 로컬 JSON 파일 캐시.
///
/// - 캔들: `candle_{symbol}_full_1d.json` (단일 누적 파일)
/// - 결과: `result_{symbol}_{tickSize}.json`
class CandleCache {
  CandleCache._();

  static final CandleCache _instance = CandleCache._();
  factory CandleCache() => _instance;

  Directory? _cacheDir;

  Future<Directory> _getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final path = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
    _cacheDir = Directory(path);
    if (!_cacheDir!.existsSync()) _cacheDir!.createSync(recursive: true);
    return _cacheDir!;
  }

  String _fileName(String symbol, [String interval = '1d']) =>
      'candle_${symbol}_full_$interval.json';

  /// 캐시된 캔들 데이터 로드 (`_full_` 파일).
  Future<List<Candle>?> load({
    required String symbol,
    required DateTime start,
    required DateTime end,
    String interval = '1d',
  }) async {
    try {
      final dir = await _getDir();
      final fullFile = File('${dir.path}/${_fileName(symbol, interval)}');
      final exists = await fullFile.exists();
      print('[CACHE] load $symbol: dir=${dir.path}, file=${_fileName(symbol, interval)} exists=$exists');

      if (!exists) return null;
      final c = await _readFile(fullFile);
      print('[CACHE] load $symbol: ${c?.length ?? 0} candles');
      return c;
    } catch (_) {
      return null;
    }
  }

  Future<List<Candle>?> _readFile(File file) async {
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _candleFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  /// 캔들 데이터를 `_full_` 파일에 누적 저장.
  ///
  /// 기존 캐시 + 새 데이터 병합 → 중복 제거 → 정렬 → 저장.
  Future<void> save({
    required String symbol,
    required DateTime start,
    required DateTime end,
    required List<Candle> candles,
    String interval = '1d',
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_fileName(symbol, interval)}');
      final fullPath = file.path;
      print('[CACHE] save $symbol: file=$fullPath, candles=${candles.length}');

      // 기존 캐시 로드
      List<Candle> existing = [];
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          existing = (jsonDecode(raw) as List<dynamic>)
              .map((e) => _candleFromJson(e as Map<String, dynamic>))
              .toList();
          print('[CACHE] save $symbol: existing=${existing.length} candles');
        } catch (_) {}
      }

      // 병합
      final all = [...existing, ...candles];
      all.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 중복 제거 (같은 timestamp)
      final seen = <DateTime>{};
      final merged = all.where((c) => seen.add(c.timestamp)).toList();

      // JSON 인코딩 분리
      final jsonStr = jsonEncode(merged.map((c) => _candleToJson(c)).toList());
      print('[CACHE] save $symbol: json length=${jsonStr.length} bytes');

      // 원자적 쓰기: 임시 파일에 먼저 쓴 후 rename (hot restart 시 원본 보호)
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(jsonStr);
      // sync로 rename (같은 파티션 내 원자적)
      tmpFile.renameSync(file.path);
      await Future.delayed(const Duration(milliseconds: 50));
      var ok = file.existsSync();
      var sz = ok ? file.lengthSync() : 0;
      print('[CACHE] save $symbol: atomic write OK=$ok size=$sz');

      // 실패 시 sync 재시도
      if (!ok || sz == 0) {
        print('[CACHE] save $symbol: atomic FAILED, retry sync...');
        final tmp2 = File('${file.path}.tmp2');
        tmp2.writeAsStringSync(jsonStr);
        tmp2.renameSync(file.path);
        ok = file.existsSync();
        sz = ok ? file.lengthSync() : 0;
        print('[CACHE] save $symbol: sync retry OK=$ok size=$sz');
      }

      if (ok && sz > 0) {
        print('[CACHE] save $symbol: FINAL OK merged=${merged.length} candles');
      } else {
        print('[CACHE] save $symbol: FINAL FAILED after retry');
      }
    } catch (e) {
      print('[CACHE] save $symbol ERROR: $e');
      // fallback: 동기 tmp→rename
      try {
        final dir = await _getDir();
        final file = File('${dir.path}/${_fileName(symbol, interval)}');
        final all2 = [...candles];
        all2.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final seen2 = <DateTime>{};
        final merged2 = all2.where((c) => seen2.add(c.timestamp)).toList();
        final json = jsonEncode(merged2.map((c) => _candleToJson(c)).toList());
        final tmp = File('${file.path}.tmp');
        tmp.writeAsStringSync(json);
        tmp.renameSync(file.path);
        print('[CACHE] save $symbol: fallback sync OK=${file.existsSync()}');
      } catch (e2) {
        print('[CACHE] save $symbol: fallback ALSO FAILED: $e2');
      }
    }
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

  String _resultFile(String symbol, double tickSize) =>
      'result_${symbol}_${tickSize.toStringAsFixed(0)}.json';

  /// 저장된 백테스트 결과 로드.
  Future<BacktestResult?> loadResult({
    required String symbol,
    required double tickSize,
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_resultFile(symbol, tickSize)}');
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
      final file = File('${dir.path}/${_resultFile(symbol, tickSize)}');
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
      final cf = File('${dir.path}/${_fileName(symbol, interval)}');
      if (await cf.exists()) await cf.delete();
      final rf = File('${dir.path}/${_resultFile(symbol, tickSize)}');
      if (await rf.exists()) await rf.delete();
    } catch (_) {}
  }
}
