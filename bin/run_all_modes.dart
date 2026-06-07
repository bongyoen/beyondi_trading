import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/backtest/domain/usecases/run_backtest.dart';

void main(List<String> args) async {
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final d = Directory(cacheDir);
  if (!d.existsSync()) { print('캐시 디렉토리 없음'); exit(1); }

  final codes = d.listSync().whereType<File>()
      .where((f) => f.path.endsWith('_full_1d.json'))
      .map((f) => RegExp(r'candle_(\d{6})_').firstMatch(f.path.split('\\').last))
      .whereType<RegExpMatch>()
      .map((m) => m.group(1)!)
      .toList();
  if (codes.isEmpty) { print('캐시 파일 없음'); exit(1); }

  print('>>> ${codes.length}개 종목 발견\n');

  final configs = ['300K_full', '10M_full', '300K_20d'];
  final configPs = {'300K_full': 300000.0, '10M_full': 10000000.0, '300K_20d': 300000.0};
  final configRecent = {'300K_full': 0, '10M_full': 0, '300K_20d': 20};

  final modes = [
    'vwap_cross', 'vwap_poc', 'hybrid', 'macd',
    'obv_div', 'vwap_scalp', 'orb', 'ema_trend',
  ];

  final cores = Platform.numberOfProcessors;
  final chunkSize = (codes.length / cores).ceil();
  final chunks = <List<String>>[];
  for (int i = 0; i < codes.length; i += chunkSize) {
    chunks.add(codes.sublist(i, (i + chunkSize).clamp(0, codes.length)));
  }

  final totalJobs = chunks.length * configs.length * modes.length;
  print('코어: $cores, 청크: ${chunks.length}개, 모드: ${modes.length}개, config: ${configs.length}개');
  print('총 작업: 88종목 × 8모드 × 3config = 2,112회 백테스트');
  print('>>> Isolate ${chunks.length}개 로딩 중... (약 3~5분)\n');

  final sw = Stopwatch()..start();
  final receivePort = ReceivePort();

  for (int ci = 0; ci < chunks.length; ci++) {
    Isolate.spawn(_worker, {
      'codes': chunks[ci],
      'cacheDir': cacheDir,
      'configs': configs,
      'configPs': configPs,
      'configRecent': configRecent,
      'modes': modes,
      'sendPort': receivePort.sendPort,
    });
  }

  // 결과 수집: {config_mode: [{code, netReturn, roi, winRate, trades, maxDrawdown, sharpeRatio}, ...]}
  final allResults = <String, List<Map<String, dynamic>>>{};
  int received = 0;
  await for (final msg in receivePort) {
    final chunk = msg as List<dynamic>;
    for (final entry in chunk) {
      final e = entry as Map<String, dynamic>;
      final key = '${e['config']}_${e['mode']}';
      allResults.putIfAbsent(key, () => []).add(e);
    }
    received++;
    final elapsed = sw.elapsedMilliseconds ~/ 1000;
    if (received % 3 == 0 || received == chunks.length) {
      print('  진행: $received/${chunks.length} 청크 완료 (${elapsed}초)');
    }
    if (received >= chunks.length) break;
  }
  receivePort.close();

  print('\n>>> 전체 연산 완료 (${sw.elapsedMilliseconds ~/ 1000}s)\n');

  // 저장
  File('$cacheDir\\all_modes_results.json').writeAsStringSync(jsonEncode(allResults));
  print('>>> JSON 저장 완료');

  // MD 리포트 생성
  _saveReport(cacheDir, allResults, configs, modes, configPs);
}

void _worker(Map<String, dynamic> msg) {
  final codes = (msg['codes'] as List).cast<String>();
  final cacheDir = msg['cacheDir'] as String;
  final configs = (msg['configs'] as List).cast<String>();
  final configPs = (msg['configPs'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
  final configRecent = (msg['configRecent'] as Map).map((k, v) => MapEntry(k as String, v as int));
  final modes = (msg['modes'] as List).cast<String>();
  final sendPort = msg['sendPort'] as SendPort;

  final results = <Map<String, dynamic>>[];
  for (final code in codes) {
    final candles = _loadCandles(code, cacheDir);
    if (candles == null || candles.length < 200) continue;
    final ts = _detectTickSize(candles);

    for (final cfgLabel in configs) {
      final principal = configPs[cfgLabel]!;
      final recent = configRecent[cfgLabel]!;
      final useCandles = recent > 0 && candles.length > recent * 390
          ? candles.sublist(candles.length - recent * 390)
          : candles;
      final useTs = recent > 0 ? _detectTickSize(useCandles) : ts;

      for (final mode in modes) {
        try {
          final r = runBacktest(
            candles: useCandles,
            tickSize: useTs,
            takeProfitTicks: 0, stopLossTicks: 0,
            stopLossPercent: 5, useAtrStop: false, atrMultiplier: 2.0,
            closeAtEndOfDay: true, mode: mode,
            commissionPercent: 0.147,
            principal: principal,
            consecutiveLossLimit: 10,
            dailyLossLimit: (principal * 0.1).clamp(30000, 1000000),
            maxTotalLoss: (principal * 0.3).clamp(50000, 5000000),
            useAtrPositionSizing: true,
            entryThresholdTicks: mode == 'vwap_cross' || mode == 'hybrid' ? 10 : 0,
            useRsiFilter: mode == 'vwap_cross' || mode == 'vwap_poc',
            longOnly: true,
          );
          results.add({
            'config': cfgLabel, 'mode': mode, 'code': code,
            'netReturn': r.netReturn, 'roi': r.roi,
            'winRate': r.winRate, 'trades': r.trades.length,
            'maxDrawdown': r.maxDrawdown, 'sharpeRatio': r.sharpeRatio,
          });
        } catch (_) {}
      }
    }
  }
  sendPort.send(results);
}

void _saveReport(String cacheDir, Map<String, List<Map<String, dynamic>>> allResults,
    List<String> configs, List<String> modes, Map<String, double> configPs) {
  var r = '# 전체 모드 백테스트 결과\n\n';
  r += '실행일: ${DateTime.now().toString().substring(0, 10)}\n\n';
  r += '총 88종목 × 8모드 × 3config = 2,112회 백테스트\n\n';

  for (final cfg in configs) {
    r += '---\n\n';
    r += '## ${_cfgLabel(cfg)} (원금 ₩${_fmt(configPs[cfg]!)})\n\n';

    // 모드별 요약 테이블
    r += '### 모드별 요약\n\n';
    r += '| 모드 | 수익종목 | 손실종목 | 승률 | 최고수익률 | 최저수익률 | 평균손익 | 평균거래 |\n';
    r += '|---|---|---|---|---|---|---|---|\n';

    final modeRows = <Map<String, dynamic>>[];
    for (final mode in modes) {
      final key = '${cfg}_$mode';
      final data = allResults[key] ?? [];
      if (data.isEmpty) continue;
      final wins = data.where((e) => (e['netReturn'] as num) > 0).length;
      final avgWr = data.map((e) => (e['winRate'] as num).toDouble()).reduce((a, b) => a + b) / data.length;
      final maxR = data.map((e) => (e['roi'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
      final minR = data.map((e) => (e['roi'] as num).toDouble()).reduce((a, b) => a < b ? a : b);
      final avgNet = data.map((e) => (e['netReturn'] as num).toDouble()).reduce((a, b) => a + b) / data.length;
      final avgTrades = data.map((e) => (e['trades'] as int).toDouble()).reduce((a, b) => a + b) / data.length;
      modeRows.add({
        'mode': mode, 'wins': wins, 'losses': data.length - wins,
        'avgWr': avgWr, 'maxR': maxR, 'minR': minR, 'avgNet': avgNet, 'avgTrades': avgTrades,
      });
    }
    modeRows.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));

    for (final row in modeRows) {
      r += '| ${(row['mode'] as String).padRight(12)} | ${row['wins']} | ${row['losses']} | ${(row['avgWr'] * 100).toStringAsFixed(1)}% | ${(row['maxR'] >= 0 ? '+' : '')}${row['maxR'].toStringAsFixed(1)}% | ${row['minR'].toStringAsFixed(1)}% | ${_fmt(row['avgNet'])} | ${row['avgTrades'].toStringAsFixed(0)} |\n';
    }

    // 모드별 상세 (Top 10)
    r += '\n### 모드별 Top 10\n\n';
    for (final mode in modes) {
      final key = '${cfg}_$mode';
      final data = allResults[key] ?? [];
      if (data.isEmpty) continue;
      final sorted = List<Map<String, dynamic>>.from(data)
        ..sort((a, b) => (b['netReturn'] as num).compareTo(a['netReturn'] as num));

      r += '#### $mode\n\n';
      r += '| 순위 | 종목 | 순손익 | 수익률 | 승률 | 거래 | MDD | Sharpe |\n';
      r += '|---|---|---|---|---|---|---|---|\n';
      for (int i = 0; i < sorted.length && i < 10; i++) {
        r += _rowMd(i + 1, sorted[i]);
      }
      r += '\n';
    }
  }

  // Config별 최적 모드 추천
  r += '---\n\n## Config별 최적 모드 추천\n\n';
  r += '| Config | 1위 모드 (수익종목) | 2위 모드 (수익종목) | 3위 모드 (수익종목) |\n';
  r += '|---|---|---|---|\n';

  for (final cfg in configs) {
    final rankings = <(String, int)>[];
    for (final mode in modes) {
      final key = '${cfg}_$mode';
      final data = allResults[key] ?? [];
      final wins = data.where((e) => (e['netReturn'] as num) > 0).length;
      rankings.add((mode, wins));
    }
    rankings.sort((a, b) => b.$2.compareTo(a.$2));
    r += '| ${_cfgLabel(cfg)} | ${rankings[0].$1} (${rankings[0].$2}) | ${rankings[1].$1} (${rankings[1].$2}) | ${rankings[2].$1} (${rankings[2].$2}) |\n';
  }

  File('$cacheDir\\all_modes_report.md').writeAsStringSync(r);
  print('>>> MD 리포트 저장 완료');
}

String _cfgLabel(String cfg) {
  switch (cfg) {
    case '300K_full': return '원금 30만원 · 전체기간';
    case '10M_full': return '원금 1,000만원 · 전체기간';
    case '300K_20d': return '원금 30만원 · 최근 20일';
    default: return cfg;
  }
}

String _rowMd(int rank, Map<String, dynamic> e) {
  final nr = (e['netReturn'] as num).toDouble();
  final roi = (e['roi'] as num).toDouble();
  final wr = (e['winRate'] as num).toDouble();
  final trades = e['trades'] as int;
  final mdd = (e['maxDrawdown'] as num).toDouble();
  final sharpe = (e['sharpeRatio'] as num).toDouble();
  return '| $rank | ${e['code']} | ${_fmt(nr)} | ${nr >= 0 ? '+' : ''}${roi.toStringAsFixed(1)}% | ${(wr * 100).toStringAsFixed(0)}% | $trades | ${_fmt(mdd.abs())} | ${sharpe.toStringAsFixed(2)} |\n';
}

List<Candle>? _loadCandles(String code, String dir) {
  try {
    final files = Directory(dir).listSync().whereType<File>()
        .where((f) => f.path.contains('candle_${code}_') && f.path.endsWith('_full_1d.json'))
        .toList();
    if (files.isEmpty) return null;
    final raw = jsonDecode(files.first.readAsStringSync()) as List<dynamic>;
    return raw.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
  } catch (_) { return null; }
}

Candle _parseCandle(Map<String, dynamic> m) => Candle(
  timestamp: DateTime.parse(m['t'] as String),
  open: (m['o'] as num).toDouble(), high: (m['h'] as num).toDouble(),
  low: (m['l'] as num).toDouble(), close: (m['c'] as num).toDouble(),
  volume: (m['v'] as num).toDouble(),
);

double _detectTickSize(List<Candle> candles) {
  final avg = candles.map((c) => c.close).reduce((a, b) => a + b) / candles.length;
  if (avg >= 100000) return 100;
  if (avg >= 10000) return 50;
  if (avg >= 5000) return 10;
  return 5;
}

String _fmt(double v) {
  if (v == 0) return '₩0';
  return v < 0
      ? '-₩${v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
      : '₩${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
