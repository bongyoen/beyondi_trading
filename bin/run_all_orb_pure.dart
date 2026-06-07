import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:beyondi_trading/entities/candle/model/candle.dart';
import 'package:beyondi_trading/features/backtest/model/usecases/run_backtest.dart';

/// 순수 ORB: range 돌파 조건만으로 백테스트 (Phase 필터 없음)
/// runBacktest()를 호출하지 않고 직접 로직 구현

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

  print('코어: $cores, 청크: ${chunks.length}개');
  print('>>> Isolate ${chunks.length}개 로딩 중... (약 30~40초)\n');

  final sw = Stopwatch()..start();
  final receivePort = ReceivePort();
  for (int ci = 0; ci < chunks.length; ci++) {
    Isolate.spawn(_worker, {
      'codes': chunks[ci],
      'cacheDir': cacheDir,
      'configs': configs,
      'sendPort': receivePort.sendPort,
    });
  }

  final allResults = <Map<String, dynamic>>[];
  int received = 0;
  await for (final msg in receivePort) {
    allResults.addAll((msg as List).cast<Map<String, dynamic>>());
    received++;
    print('  진행: $received/${chunks.length} 청크 완료 (${sw.elapsedMilliseconds ~/ 1000}초)');
    if (received >= chunks.length) break;
  }
  receivePort.close();

  print('\n>>> 전체 연산 완료 (${sw.elapsedMilliseconds ~/ 1000}s)\n');

  // config별 정렬 + 출력 + 저장
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
      print('${(i+1).toString().padLeft(2)}  ${e['code']}  ${sign}${_fmt(nr).padLeft(10)}  ${sign}${roi.toStringAsFixed(1).padLeft(6)}%  ${(wr*100).toStringAsFixed(0).padLeft(3)}%  ${trades.toString().padLeft(4)}  ${_fmt(mdd.abs()).padLeft(10)}  ${sharpe.toStringAsFixed(2).padLeft(6)}');
    }
    File('$cacheDir\\orb_batch_$label.json').writeAsStringSync(jsonEncode(batch));
    print('  저장 완료\n');
  }

  // MD 생성
  _saveReport(cacheDir);
  print('>>> MD 리포트 저장 완료');
}

/// Isolate worker: 순수 ORB 백테스트 직접 실행
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

      // 순수 ORB 백테스트 (Phase 필터 없음)
      final result = _runPureOrb(useCandles, ts, principal, label);

      results.add({
        'config': result['config'],
        'code': code,
        'netReturn': result['netReturn'],
        'roi': result['roi'],
        'winRate': result['winRate'],
        'trades': result['trades'],
        'maxDrawdown': result['maxDrawdown'],
        'sharpeRatio': result['sharpeRatio'],
      });
    }
  }
  sendPort.send(results);
}

/// 순수 ORB: range 돌파 + 5% 종가 손절 + 장마감 청산 (Phase 필터 없음)
Map<String, dynamic> _runPureOrb(List<Candle> candles, double ts, double principal, String label) {
  const commPct = 0.147;
  const rangeMin = 30;
  const stopLossPct = 5.0;

  int posSize(double entryPrice) => max(1, (principal / entryPrice).floor());

  final trades = <Map<String, dynamic>>[];
  TradeSignal? position; // null=none, strongBuy=long
  double? entryPrice;
  DateTime? entryTime;
  double totalPnl = 0;
  double totalComm = 0;
  int consecLoss = 0;
  double dailyPnl = 0;
  int lastDayKey = -1;
  bool stopped = false;
  const maxTotalLoss = 100000.0;
  const dailyLossLimit = 50000.0;
  const consecLimit = 10;

  double dayHigh = 0, dayLow = 0;
  int rangeElapsed = 0;
  bool rangeComplete = false;

  void closePos(double exitPrice, DateTime exitTime) {
    if (position == null || entryPrice == null || entryTime == null) return;
    final pos = posSize(entryPrice!);
    final rawPnl = (exitPrice - entryPrice!) * pos;
    final comm = (entryPrice! + exitPrice) * pos * commPct / 100;
    final netPnl = rawPnl - comm;
    totalPnl += netPnl; totalComm += comm;
    dailyPnl += netPnl;
    if (netPnl < 0) consecLoss++; else consecLoss = 0;
    trades.add({
      'entry': entryTime!.toIso8601String(), 'exit': exitTime.toIso8601String(),
      'entryPrice': entryPrice!, 'exitPrice': exitPrice,
      'pnl': netPnl, 'comm': comm,
    });
    position = null; entryPrice = null; entryTime = null;
  }

  for (int i = 0; i < candles.length; i++) {
    final c = candles[i];
    final isNewDay = i == 0 || candles[i].timestamp.day != candles[i-1].timestamp.day;
    final isLastOfDay = (i + 1 >= candles.length ||
        candles[i + 1].timestamp.day != c.timestamp.day);

    if (position != null) {
      // 청산 체크: 5% 손절 (종가 기준)
      if (stopLossPct > 0) {
        final pnlPct = (c.close - entryPrice!) / entryPrice! * 100;
        if (pnlPct <= -stopLossPct) { closePos(c.close, c.timestamp); }
      }
      // 장마감 청산
      if (isLastOfDay && position != null) { closePos(c.close, c.timestamp); }
      if (position != null) continue;
    }

    // 손실 제한
    final dayKey = c.timestamp.year * 10000 + c.timestamp.month * 100 + c.timestamp.day;
    if (dayKey != lastDayKey) { lastDayKey = dayKey; dailyPnl = 0; }
    if (maxTotalLoss > 0 && totalPnl <= -maxTotalLoss) { stopped = true; }
    if (stopped) continue;
    if (dailyLossLimit > 0 && dailyPnl <= -dailyLossLimit) continue;
    if (consecLimit > 0 && consecLoss >= consecLimit) continue;

    // ORB: range 트래킹
    if (isNewDay) {
      dayHigh = c.close; dayLow = c.close;
      rangeElapsed = 0; rangeComplete = false;
    }
    if (!rangeComplete) {
      rangeElapsed++;
      if (c.close > dayHigh) dayHigh = c.close;
      if (c.close < dayLow) dayLow = c.close;
      if (rangeElapsed >= rangeMin) rangeComplete = true;
    }

    // 순수 ORB 진입: range 돌파만 (ADX/VWAP/Volume/CI 없음)
    if (rangeComplete && !isNewDay && position == null) {
      if (c.close > dayHigh && c.high >= dayHigh * 1.001) {
        position = TradeSignal.strongBuy;
        entryPrice = c.close;
        entryTime = c.timestamp;
      }
    }
  }

  // 마지막 포지션 청산
  if (position != null && entryPrice != null && entryTime != null) {
    final last = candles.last;
    closePos(last.close, last.timestamp);
  }

  final wins = trades.where((t) => t['pnl'] > 0).length;
  double peak = 0, mdd = 0, runPnl = 0;
  for (final t in trades) {
    runPnl += t['pnl'];
    if (runPnl > peak) peak = runPnl;
    if (peak - runPnl > mdd) mdd = peak - runPnl;
  }

  return {
    'config': label, 'netReturn': totalPnl, 'roi': principal > 0 ? totalPnl / principal * 100 : 0,
    'winRate': trades.isEmpty ? 0.0 : wins / trades.length,
    'trades': trades.length, 'maxDrawdown': mdd,
    'sharpeRatio': trades.length > 1 ? _calcSharpe(trades) : 0,
  };
}

double _calcSharpe(List<Map<String, dynamic>> trades) {
  final returns = trades.map((t) => t['pnl'] as double).toList();
  final avg = returns.reduce((a, b) => a + b) / returns.length;
  final variance = returns.map((r) => (r - avg) * (r - avg)).reduce((a, b) => a + b) / returns.length;
  final stdDev = sqrt(variance);
  return stdDev == 0 ? 0 : avg / stdDev;
}

void _saveReport(String cacheDir) {
  final configs = [
    ('300K_full', '원금 30만원 · 전체기간'),
    ('10M_full', '원금 1,000만원 · 전체기간'),
    ('300K_20d', '원금 30만원 · 최근 20일'),
  ];

  var r = '# ORB 백테스트 결과 (Pure)\n\n';
  r += '실행일: ${DateTime.now().toString().substring(0, 10)}\n\n';
  r += '## Config별 요약\n\n';
  r += '| Config | 종목수 | 수익 | 손실 | 최고수익률 | 최저수익률 | 평균손익 |\n|---|---|---|---|---|---|---|\n';

  for (final c in configs) {
    final f = File('$cacheDir\\orb_batch_${c.$1}.json');
    if (!f.existsSync()) continue;
    final data = (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final wins = data.where((e) => (e['netReturn'] as num) > 0).length;
    final maxR = data.map((e) => (e['roi'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    final minR = data.map((e) => (e['roi'] as num).toDouble()).reduce((a, b) => a < b ? a : b);
    final avgR = data.map((e) => (e['netReturn'] as num).toDouble()).reduce((a, b) => a + b) / data.length;
    r += '| ${c.$2} | ${data.length} | $wins | ${data.length - wins} | ${maxR.toStringAsFixed(1)}% | ${minR.toStringAsFixed(1)}% | ${_fmt(avgR)} |\n';
  }

  r += '\n---\n\n';

  for (final c in configs) {
    final f = File('$cacheDir\\orb_batch_${c.$1}.json');
    if (!f.existsSync()) continue;
    final data = (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    data.sort((a, b) => (b['netReturn'] as num).compareTo(a['netReturn'] as num));

    r += '## ${c.$2}\n\n';
    r += '| 순위 | 종목 | 순손익 | 수익률 | 승률 | 거래 | MDD | Sharpe |\n|---|---|---|---|---|---|---|---|\n';
    for (int i = 0; i < data.length; i++) {
      final e = data[i];
      final nr = (e['netReturn'] as num).toDouble();
      final roi = (e['roi'] as num).toDouble();
      final wr = (e['winRate'] as num).toDouble();
      final trades = e['trades'] as int;
      final mdd = (e['maxDrawdown'] as num).toDouble();
      final sharpe = (e['sharpeRatio'] as num).toDouble();
      r += '| ${i+1} | ${e['code']} | ${_fmt(nr)} | ${nr >= 0 ? '+' : ''}${roi.toStringAsFixed(1)}% | ${(wr*100).toStringAsFixed(0)}% | $trades | ${_fmt(mdd.abs())} | ${sharpe.toStringAsFixed(2)} |\n';
    }
    r += '\n';
  }

  File('$cacheDir\\orb_batch_report_pure.md').writeAsStringSync(r);
}

enum TradeSignal { strongBuy, strongSell, neutral }

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
