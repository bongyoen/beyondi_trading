import 'dart:convert';
import 'dart:io';

import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/backtest/domain/usecases/run_backtest.dart';

void main(List<String> args) {
  final stock = _arg(args, '--stock') ?? '005930';
  final mode = _arg(args, '--mode') ?? 'all';

  final candles = _loadCandles(stock);
  if (candles == null || candles.length < 100) {
    print('에러: $stock 캔들 데이터를 찾을 수 없거나 부족합니다');
    exit(1);
  }
  print('>>> $stock 캔들 ${candles.length}개 로드됨');
  print('>>> 기간: ${candles.first.timestamp} ~ ${candles.last.timestamp}');

  final allResults = <ParamResult>[];
  final modes = ['vwap_cross', 'vwap_poc', 'macd', 'obv_div'];
  final timeFilter = 1000; // 10:00
  final timeEnd = 1430;    // 14:30
  final entryValues = [0, 5, 10, 15, 20];
  final tpValues = [0, 15, 30];
  final slValues = [0, 5, 10];

  for (final strat in modes) {
    if (mode != 'all' && mode != strat) continue;
    print('\n=== 전략: $strat (시간필터 ${timeFilter ~/ 100}:${(timeFilter % 100).toString().padLeft(2, '0')}~${timeEnd ~/ 100}:${(timeEnd % 100).toString().padLeft(2, '0')}) ===');

    int count = 0;
    final total = entryValues.length * tpValues.length * slValues.length;
    for (final e in entryValues) {
      for (final tp in tpValues) {
        for (final sl in slValues) {
          count++;
          if (count % 20 == 0) print('  진행: $count/$total');
          final result = runBacktest(
            candles: candles,
            tickSize: _detectTickSize(candles),
            entryThresholdTicks: e.toDouble(),
            takeProfitTicks: tp.toDouble(),
            stopLossTicks: sl.toDouble(),
            tradeStartTime: timeFilter,
            tradeEndTime: timeEnd,
            closeAtEndOfDay: true,
            mode: strat,
            commissionPercent: 0.147,
          );
          allResults.add(ParamResult(
            label: '$strat 진입$e/익절$tp/손절$sl',
            params: {':strat': strat, ':entry': e, ':tp': tp, ':sl': sl},
            netReturn: result.netReturn,
            totalReturn: result.totalReturn,
            totalCommission: result.totalCommission,
            totalSignals: result.totalSignals,
            winRate: result.winRate,
            sharpeRatio: result.sharpeRatio,
            maxDrawdown: result.maxDrawdown,
          ));
        }
      }
    }
    print('  $strat: $total개 조합 완료');
  }

  allResults.sort((a, b) => b.netReturn.compareTo(a.netReturn));
  _saveResults(stock, allResults);
  print('\n=== 종합 TOP 10 ===');
  _printTop(stock, allResults, 10);
}

String? _arg(List<String> args, String name) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == name) return args[i + 1];
  }
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}

List<Candle>? _loadCandles(String symbol) {
  final dir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  if (dir.isEmpty) return null;
  final d = Directory(dir);
  if (!d.existsSync()) return null;

  // _full_ 파일 우선
  final fullFile = File('$dir\\candle_${symbol}_full_1d.json');
  if (fullFile.existsSync()) {
    final raw = jsonDecode(fullFile.readAsStringSync()) as List<dynamic>;
    return raw.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
  }

  // 구형 파일 스캔 → _full_로 마이그레이션
  final oldFiles = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_${symbol}_') && !f.path.contains('_full_') && f.path.endsWith('_1d.json'))
      .toList();
  if (oldFiles.isEmpty) return null;
  oldFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  final raw = jsonDecode(oldFiles.first.readAsStringSync()) as List<dynamic>;
  fullFile.writeAsStringSync(jsonEncode(raw));
  for (final f in oldFiles) { try { f.deleteSync(); } catch (_) {} }
  return raw.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
}

Candle _parseCandle(Map<String, dynamic> m) => Candle(
    timestamp: DateTime.parse(m['t'] as String),
    open: (m['o'] as num).toDouble(),
    high: (m['h'] as num).toDouble(),
    low: (m['l'] as num).toDouble(),
    close: (m['c'] as num).toDouble(),
    volume: (m['v'] as num).toDouble(),
);

double _detectTickSize(List<Candle> candles) {
  final avg = candles.map((c) => c.close).reduce((a, b) => a + b) / candles.length;
  if (avg >= 100000) return 100;
  if (avg >= 10000) return 50;
  if (avg >= 5000) return 10;
  return 5;
}

ParamResult? _bestBy(List<ParamResult> results) {
  if (results.isEmpty) return null;
  results.sort((a, b) => b.netReturn.compareTo(a.netReturn));
  return results.first;
}

void _printTop(String stock, List<ParamResult> results, int n) {
  print('\n=== $stock TOP $n ===');
  for (int i = 0; i < n && i < results.length; i++) {
    final r = results[i];
    final sign = r.netReturn >= 0 ? '+' : '';
    print('${i + 1}위: ${r.label} → ${sign}${r.netReturn.toStringAsFixed(0)}원'
        ' (수수료 ${r.totalCommission.toStringAsFixed(0)}원, '
        '${r.totalSignals}건, 승률 ${(r.winRate * 100).toStringAsFixed(1)}%, '
        'Sharpe ${r.sharpeRatio.toStringAsFixed(2)})');
  }
}

void _saveResults(String stock, List<ParamResult> results) {
  final dir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final file = File('$dir\\optimize_${stock}_results.json');
  final data = results.map((r) => {
    'label': r.label,
    'params': r.params,
    'netReturn': r.netReturn,
    'totalReturn': r.totalReturn,
    'totalCommission': r.totalCommission,
    'totalSignals': r.totalSignals,
    'winRate': r.winRate,
    'sharpeRatio': r.sharpeRatio,
    'maxDrawdown': r.maxDrawdown,
  }).toList();
  file.writeAsStringSync(jsonEncode(data));
  print('\n결과 저장됨: ${file.path}');
}

class ParamResult {
  final String label;
  final Map<String, dynamic> params;
  final double netReturn;
  final double totalReturn;
  final double totalCommission;
  final int totalSignals;
  final double winRate;
  final double sharpeRatio;
  final double maxDrawdown;

  ParamResult({
    required this.label,
    required this.params,
    required this.netReturn,
    required this.totalReturn,
    required this.totalCommission,
    required this.totalSignals,
    required this.winRate,
    required this.sharpeRatio,
    required this.maxDrawdown,
  });
}
