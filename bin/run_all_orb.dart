import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/backtest/domain/usecases/run_backtest.dart';

void main(List<String> args) async {
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final d = Directory(cacheDir);
  if (!d.existsSync()) { print('캐시 디렉토리 없음'); exit(1); }

  // 코드 목록만 수집 (각 isolate가 직접 파일 읽음)
  final codes = d.listSync().whereType<File>()
      .where((f) => f.path.endsWith('_full_1d.json'))
      .map((f) => RegExp(r'candle_(\d{6})_').firstMatch(f.path.split('\\').last))
      .whereType<RegExpMatch>()
      .map((m) => m.group(1)!)
      .toList();
  if (codes.isEmpty) { print('캐시 파일 없음'); exit(1); }

  print('>>> ${codes.length}개 종목 발견\n');

  final configs = [
    {'label': '300K_full', 'p': 300000.0, 'recent': 0},
    {'label': '10M_full', 'p': 10000000.0, 'recent': 0},
    {'label': '300K_20d', 'p': 300000.0, 'recent': 20},
  ];

  final cores = Platform.numberOfProcessors;
  final chunkSize = (codes.length / cores).ceil();
  final chunks = <List<String>>[];
  for (int i = 0; i < codes.length; i += chunkSize) {
    chunks.add(codes.sublist(i, (i + chunkSize).clamp(0, codes.length)));
  }

  /* --- 시간 추정 ---
     219s 순차 / 8코어 ≈ 27s + Isolate 오버헤드(3s) + 파일읽기(5s) ≈ 35s
     실제로는 메모리 대역폭 한계로 35~50s 예상
  */
  print('코어: $cores, 청크: ${chunks.length}개 (청크당 ~${chunkSize}종목)');
  print('예상 시간: 약 ${(219 / cores + 5).round()}초\n');

  print('>>> Isolate ${chunks.length}개 로딩 중... (약 ${((219 / (cores / 2)) + 5).round()}~${((219 / cores) + 10).round()}초 소요)');
  // Isolate 병렬 실행 (청크당 1개, 각 Isolate가 3개 config 실행)
  final sw = Stopwatch()..start();
  final receivePort = ReceivePort();
  final totalJobs = chunks.length;

  for (int ci = 0; ci < chunks.length; ci++) {
    Isolate.spawn(_worker, {
      'codes': chunks[ci],
      'cacheDir': cacheDir,
      'configs': configs,
      'sendPort': receivePort.sendPort,
    });
  }

  // 결과 수집
  final allResults = <Map<String, dynamic>>[];
  int received = 0;
  await for (final msg in receivePort) {
    final chunk = msg as List<dynamic>;
    allResults.addAll(chunk.cast<Map<String, dynamic>>());
    received++;
    final elapsed = sw.elapsedMilliseconds ~/ 1000;
    print('  진행: $received/$totalJobs 청크 완료 (${elapsed}초)');
    if (received >= totalJobs) break;
  }
  receivePort.close();

  print('\n>>> 전체 연산 완료 (${sw.elapsedMilliseconds ~/ 1000}s)\n');

  // config별 분류 + 출력
  for (final cfg in configs) {
    final label = cfg['label'] as String;
    final batch = allResults.where((r) => r['config'] == label).toList();
    batch.sort((a, b) => (b['netReturn'] as num).compareTo(a['netReturn'] as num));

    print('${'=' * 65}');
    print('  $label  (원금: ₩${_fmt(cfg['p'] as double)})');
    print('${'=' * 65}');
    print('순위 종목    순손익         수익률   승률    거래  MDD      Sharpe');
    print('${'-' * 65}');
    for (int i = 0; i < batch.length; i++) {
      final e = batch[i];
      final nr = (e['netReturn'] as num).toDouble();
      final roi = (e['roi'] as num).toDouble();
      final wr = (e['winRate'] as num).toDouble();
      final trades = e['trades'] as int;
      final mdd = (e['maxDrawdown'] as num).toDouble();
      final sharpe = (e['sharpeRatio'] as num).toDouble();
      final sign = nr >= 0 ? '+' : '';
      print('${(i+1).toString().padLeft(2)}  ${e['code']}  ${sign}${_fmt(nr).padLeft(10)}  ${sign}${roi.toStringAsFixed(1).padLeft(6)}%  ${(wr*100).toStringAsFixed(0).padLeft(3)}%  ${trades.toString().padLeft(4)}  ${mdd.toStringAsFixed(0).padLeft(8)}  ${sharpe.toStringAsFixed(2).padLeft(6)}');
    }
    final outFile = File('$cacheDir\\orb_batch_$label.json');
    outFile.writeAsStringSync(jsonEncode(batch));
    print('  저장 완료\n');
  }
}

String _fmt(double v) {
  if (v == 0) return '₩0';
  return v < 0
      ? '-₩${v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
      : '₩${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

/// Isolate worker: codes 목록의 캔들 읽기 + 3개 config 백테스트 → 결과 반환
void _worker(Map<String, dynamic> msg) {
  final codes = (msg['codes'] as List).cast<String>();
  final cacheDir = msg['cacheDir'] as String;
  final configs = (msg['configs'] as List).cast<Map<String, dynamic>>();
  final sendPort = msg['sendPort'] as SendPort;

  final results = <Map<String, dynamic>>[];
  for (final code in codes) {
    final candles = _loadCandles(code, cacheDir);
    if (candles == null || candles.length < 200) continue;

    final ts = _detectTickSize(candles);

    for (final cfg in configs) {
      final label = cfg['label'] as String;
      final principal = (cfg['p'] as num).toDouble();
      final recent = cfg['recent'] as int;

      final useCandles = recent > 0 && candles.length > recent * 390
          ? candles.sublist(candles.length - recent * 390)
          : candles;

      final r = runBacktest(
        candles: useCandles,
        tickSize: ts,
        takeProfitTicks: 0, stopLossTicks: 0,
        stopLossPercent: 5, useAtrStop: false, atrMultiplier: 2.0,
        closeAtEndOfDay: true, mode: 'orb',
        commissionPercent: 0.147,
        principal: principal,
        consecutiveLossLimit: 10,
        dailyLossLimit: (principal * 0.1).clamp(30000, 1000000),
        maxTotalLoss: (principal * 0.3).clamp(50000, 5000000),
        useAtrPositionSizing: true,
      );

      results.add({
        'config': label,
        'code': code,
        'netReturn': r.netReturn,
        'roi': r.roi,
        'winRate': r.winRate,
        'trades': r.trades.length,
        'maxDrawdown': r.maxDrawdown,
        'sharpeRatio': r.sharpeRatio,
      });
    }
  }
  sendPort.send(results);
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
