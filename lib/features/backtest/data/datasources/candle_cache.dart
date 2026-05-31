import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/candle.dart';

/// 캔들 데이터 로컬 JSON 파일 캐시.
///
/// `{symbol}_{start}_{end}_{interval}.json` 형태로 저장.
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
}
