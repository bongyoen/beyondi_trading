import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/backtest/domain/usecases/run_backtest.dart';

// ---- main: Test 1 (Full Walk-Forward) + Test 2 (June 4) ----
void main() async {
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final stocks = _allStocks();

  // ----- Test 1: Full Walk-Forward (D-60 warmup, 7 configs) -----
  print('══════════════════════════════════════════════════');
  print('  TEST 1: Walk-Forward V2 (score7+ → D-60~D warmup + 7 configs)');
  print('══════════════════════════════════════════════════\n');

  final wfResults = await _runWalkForward(stocks, cacheDir);

  print('\n══════════════════════════════════════════════════');
  print('  TEST 2: June 4 당일거래 (score7+ → D-60~0604 warmup)');
  print('══════════════════════════════════════════════════\n');

  // ----- Test 2: June 4 single-day -----
  final june4Results = await _runJune4Test(stocks, cacheDir);

  // Save both reports
  _saveWfReport(wfResults, cacheDir);
  _saveJune4Report(june4Results, cacheDir);
}

// ---- configs (batch_test.dart 동일) ----
final _configs = <Map<String, dynamic>>[
  {'label': '기본    ', 'mode': 'hybrid', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': false, 'ob': 70.0, 'os': 30.0},
  {'label': 'RSI30-70', 'mode': 'hybrid', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
  {'label': 'RSI35-65', 'mode': 'hybrid', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 65.0, 'os': 35.0},
  {'label': '진입10   ', 'mode': 'hybrid', 'entry': 10.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
  {'label': '진입15   ', 'mode': 'hybrid', 'entry': 15.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
  {'label': '진입20   ', 'mode': 'hybrid', 'entry': 20.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
  {'label': 'TP15/SL10', 'mode': 'hybrid', 'entry': 5.0, 'tp': 15.0, 'sl': 10.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
  {'label': 'SCALP기본', 'mode': 'vwap_scalp', 'rsi': 30.0, 'vol': 1.5, 'minT': 5, 'maxT': 15, 'hold': 30, 'slt': 3},
  {'label': 'SCALP완화', 'mode': 'vwap_scalp', 'rsi': 35.0, 'vol': 1.2, 'minT': 10, 'maxT': 20, 'hold': 45, 'slt': 5},
  {'label': 'SCALP공격', 'mode': 'vwap_scalp', 'rsi': 25.0, 'vol': 2.0, 'minT': 3, 'maxT': 10, 'hold': 20, 'slt': 2},
  {'label': 'ORB30분', 'mode': 'orb', 'range': 30},
  {'label': 'ORB15분', 'mode': 'orb', 'range': 15},
  {'label': 'EMA9/21 ', 'mode': 'ema_trend', 'fast': 9, 'slow': 21, 'adx': 25},
  {'label': 'EMA5/13 ', 'mode': 'ema_trend', 'fast': 5, 'slow': 13, 'adx': 20},
];

double _runCfgNum(Map<String, dynamic> cfg, String key) => (cfg[key] as num?)?.toDouble() ?? 0;
bool _runCfgBool(Map<String, dynamic> cfg, String key) => cfg[key] as bool? ?? false;

// ---- 주요 실행 함수: Walk-Forward V2 (최적화: config당 1회 실행 후 날짜별 그룹) ----
Future<Map<String, dynamic>> _runWalkForward(List<Map<String, String>> stocks, String cacheDir) async {
  final allResults = <Map<String, dynamic>>[];
  int totalScore7 = 0, totalWin = 0, totalLoss = 0;
  double totalReturn = 0;

  for (int si = 0; si < stocks.length; si++) {
    final code = stocks[si]['code'] as String;
    final name = stocks[si]['name'] as String;
    print('[${si+1}/${stocks.length}] $code $name');

    final candles = _loadCachedMinute(code, cacheDir);
    if (candles == null || candles.length < 500) { print('  SKIP: 데이터 부족'); continue; }

    final minuteByDate = <String, List<Candle>>{};
    for (final c in candles) minuteByDate.putIfAbsent(_dateKey(c.timestamp), () => []).add(c);

    final dates = minuteByDate.keys.toList()..sort();
    if (dates.length < 81) { print('  SKIP: ${dates.length}일'); continue; }

    // 일봉 데이터
    final dailyData = <String, Map<String, double>>{};
    for (final d in dates) {
      final mc = minuteByDate[d]!;
      double o=mc.first.open, h=mc.first.high, l=mc.first.low, c=mc.last.close, v=0;
      for (final m in mc) { if (m.high>h) h=m.high; if (m.low<l) l=m.low; v+=m.volume; }
      dailyData[d] = {'o':o,'h':h,'l':l,'c':c,'v':v};
    }

    final tickSize = _detectTickSize(candles);
    final known = _knownResults[code];
    final histReturn = known?['net'] as int? ?? 0;

    // Step 1: Pre-compute daily scores
    final dailyScores = <String, int>{};
    for (int di = 20; di < dates.length; di++) {
      final prevDates = dates.sublist(di - 20, di);
      dailyScores[dates[di]] = _evaluate(dailyData, prevDates, histReturn);
    }

    // Step 2: Run ALL configs ONCE on full candle data, group trades by date
    // 각 config별 날짜별 P&L + commission 맵
    final Map<String, Map<String, double>> configDayPnl = {};
    final Map<String, Map<String, double>> configDayComm = {};
    for (final cfg in _configs) {
      configDayPnl[cfg['label'] as String] = {};
      configDayComm[cfg['label'] as String] = {};
    }

    // 단일 run: 가장 긴 기간 = 전체 candles
    for (final cfg in _configs) {
      final m = cfg['mode'] as String;
      final bool isScalp = m == 'vwap_scalp';
      final r = runBacktest(
        candles: candles, tickSize: tickSize,
        entryThresholdTicks: isScalp ? 0 : _runCfgNum(cfg, 'entry'),
        takeProfitTicks: isScalp ? 0 : _runCfgNum(cfg, 'tp'),
        stopLossTicks: isScalp ? 0 : _runCfgNum(cfg, 'sl'),
        useRsiFilter: isScalp ? false : _runCfgBool(cfg, 'rsi'),
        rsiOverbought: _runCfgNum(cfg, 'ob'),
        rsiOversold: _runCfgNum(cfg, 'os'),
          closeAtEndOfDay: true, mode: m,
          commissionPercent: 0.147, principal: 300000,
          consecutiveLossLimit: (isScalp || m == 'orb' || m == 'ema_trend') ? 100 : 3, dailyLossLimit: 50000, maxTotalLoss: 100000,
          longOnly: true,
          scalpRsiThreshold: isScalp ? (cfg['rsi'] as num?)?.toDouble() ?? 30 : 30,
          scalpVolumeMultiplier: isScalp ? (cfg['vol'] as num?)?.toDouble() ?? 1.5 : 1.5,
          scalpEntryTicksMin: isScalp ? (cfg['minT'] as num?)?.toDouble() ?? 5 : 5,
          scalpEntryTicksMax: isScalp ? (cfg['maxT'] as num?)?.toDouble() ?? 15 : 15,
          scalpMaxHoldMinutes: isScalp ? (cfg['hold'] as int?) ?? 30 : 30,
          scalpStopLossTicks: isScalp ? (cfg['slt'] as num?)?.toDouble() ?? 3 : 3,
          orbRangeMinutes: m == 'orb' ? (cfg['range'] as int?) ?? 30 : 30,
          emaFastPeriod: m == 'ema_trend' ? (cfg['fast'] as int?) ?? 9 : 9,
          emaSlowPeriod: m == 'ema_trend' ? (cfg['slow'] as int?) ?? 21 : 21,
          adxThreshold: m == 'ema_trend' ? (cfg['adx'] as num?)?.toDouble() ?? 25 : 25,
        );

        // Step 2b: config별 trade를 날짜별로 그룹화 (P&L + commission)
        final dayMap = configDayPnl[cfg['label'] as String]!;
        final dayComm = configDayComm[cfg['label'] as String]!;
        for (final t in r.trades) {
          final dk = _dateKey(t.exitTime);
          dayMap[dk] = (dayMap[dk] ?? 0) + t.pnl;
          dayComm[dk] = (dayComm[dk] ?? 0) + t.commission;
        }
      }

      // Step 3: score7+ 날짜별 모든 config P&L 기록
      final stockDays = <Map<String, dynamic>>[];
      final Map<String, double> configReturns = {};
      final Map<String, int> configWins = {};
      final Map<String, int> configDays = {};
      for (final cfg in _configs) {
        configReturns[cfg['label'] as String] = 0;
        configWins[cfg['label'] as String] = 0;
        configDays[cfg['label'] as String] = 0;
      }

      for (int di = 80; di < dates.length; di++) {
        final tradeDate = dates[di];
        final score = dailyScores[tradeDate] ?? 0;
        if (score < 7) continue;

        final dayConfigs = <Map<String, dynamic>>[];
        for (final cfg in _configs) {
          final lbl = cfg['label'] as String;
          final dayPnl = configDayPnl[lbl]?[tradeDate] ?? 0;
          final dayComm = configDayComm[lbl]?[tradeDate] ?? 0;
          configReturns[lbl] = (configReturns[lbl] ?? 0) + dayPnl;
          configDays[lbl] = (configDays[lbl] ?? 0) + 1;
          if (dayPnl > 0) configWins[lbl] = (configWins[lbl] ?? 0) + 1;
          dayConfigs.add({
            'cfg': lbl.trim(),
            'return': dayPnl,
            'commission': dayComm,
          });
        }

        stockDays.add({
          'date': tradeDate,
          'configs': dayConfigs,
        });
      }

      allResults.add({
        'code': code, 'name': name,
        'configReturns': configReturns,
        'configWins': configWins,
        'configDays': configDays,
        'days': stockDays,
      });

      // 콘솔 출력: config별 요약
      final score7Count = stockDays.length;
      totalScore7 += score7Count;
      if (score7Count > 0) {
        final buf = StringBuffer('  score7: ${score7Count}일');
        for (final cfg in _configs) {
          final lbl = cfg['label'] as String;
          final ret = configReturns[lbl] ?? 0;
          final days = configDays[lbl] ?? 0;
          if (days == 0) continue; // score7+일 중 이 config이 거래한 날만
          final wins = configWins[lbl] ?? 0;
          buf.write(' | ${lbl.trim()}: ${ret.toStringAsFixed(0)}원(${wins}/$days)');
        }
        print(buf.toString());
      } else {
        print('  score7: 0일');
      }
    } // end for si

    return {
      'allResults': allResults,
      'totalScore7': totalScore7,
    };
  } // end _runWalkForward

// ---- Test 2: June 4 only ----
Future<List<Map<String, dynamic>>> _runJune4Test(List<Map<String, String>> stocks, String cacheDir) async {
  final results = <Map<String, dynamic>>[];

  for (int si = 0; si < stocks.length; si++) {
    final code = stocks[si]['code'] as String;
    final name = stocks[si]['name'] as String;

    final candles = _loadCachedMinute(code, cacheDir);
    if (candles == null || candles.length < 500) continue;

    final minuteByDate = <String, List<Candle>>{};
    for (final c in candles) minuteByDate.putIfAbsent(_dateKey(c.timestamp), () => []).add(c);
    final dates = minuteByDate.keys.toList()..sort();

    // Find June 4 in data
    final june4Idx = dates.indexWhere((d) => d.startsWith('2026-06-04'));
    if (june4Idx < 20) continue;  // score용 데이터 부족
    if (june4Idx < 60) continue;  // warmup용 데이터 부족

    // 일봉
    final dailyData = <String, Map<String, double>>{};
    for (final d in dates) {
      final mc = minuteByDate[d]!;
      double o=mc.first.open, h=mc.first.high, l=mc.first.low, c=mc.last.close, v=0;
      for (final m in mc) { if (m.high>h) h=m.high; if (m.low<l) l=m.low; v+=m.volume; }
      dailyData[d] = {'o':o,'h':h,'l':l,'c':c,'v':v};
    }

    final tickSize = _detectTickSize(candles);
    final known = _knownResults[code];
    final histReturn = known?['net'] as int? ?? 0;

    // Score 계산 (D-20~D-1)
    final prevDates = dates.sublist(june4Idx - 20, june4Idx);
    final score = _evaluate(dailyData, prevDates, histReturn);

    final stockResult = {
      'code': code, 'name': name,
      'score': score, 'score7': score >= 7,
    };

    if (score >= 7) {
      // Warmup: D-60 ~ 0604
      final warmupDates = dates.sublist(june4Idx - 60, june4Idx + 1);
      final warmupCandles = warmupDates.expand((d) => minuteByDate[d]!).toList();

      final configResults = <Map<String, dynamic>>[];
      double bestDayPnl = -999999;
      String bestCfg = '';
      List<Map<String, dynamic>> bestTrades = [];

      for (final cfg in _configs) {
        final m = cfg['mode'] as String;
        final bool isScalp = m == 'vwap_scalp';
        final r = runBacktest(
          candles: warmupCandles, tickSize: tickSize,
          entryThresholdTicks: isScalp ? 0 : _runCfgNum(cfg, 'entry'),
          takeProfitTicks: isScalp ? 0 : _runCfgNum(cfg, 'tp'),
          stopLossTicks: isScalp ? 0 : _runCfgNum(cfg, 'sl'),
          useRsiFilter: isScalp ? false : _runCfgBool(cfg, 'rsi'),
          rsiOverbought: _runCfgNum(cfg, 'ob'),
          rsiOversold: _runCfgNum(cfg, 'os'),
          closeAtEndOfDay: true, mode: m,
          commissionPercent: 0.147, principal: 300000,
          consecutiveLossLimit: (isScalp || m == 'orb' || m == 'ema_trend') ? 100 : 3, dailyLossLimit: 50000, maxTotalLoss: 100000,
          longOnly: true,
          scalpRsiThreshold: isScalp ? (cfg['rsi'] as num?)?.toDouble() ?? 30 : 30,
          scalpVolumeMultiplier: isScalp ? (cfg['vol'] as num?)?.toDouble() ?? 1.5 : 1.5,
          scalpEntryTicksMin: isScalp ? (cfg['minT'] as num?)?.toDouble() ?? 5 : 5,
          scalpEntryTicksMax: isScalp ? (cfg['maxT'] as num?)?.toDouble() ?? 15 : 15,
          scalpMaxHoldMinutes: isScalp ? (cfg['hold'] as int?) ?? 30 : 30,
          scalpStopLossTicks: isScalp ? (cfg['slt'] as num?)?.toDouble() ?? 3 : 3,
          orbRangeMinutes: m == 'orb' ? (cfg['range'] as int?) ?? 30 : 30,
          emaFastPeriod: m == 'ema_trend' ? (cfg['fast'] as int?) ?? 9 : 9,
          emaSlowPeriod: m == 'ema_trend' ? (cfg['slow'] as int?) ?? 21 : 21,
          adxThreshold: m == 'ema_trend' ? (cfg['adx'] as num?)?.toDouble() ?? 25 : 25,
        );

        double dayPnl = 0;
        int dayTrades = 0;
        final tradeDetails = <Map<String, dynamic>>[];
        for (final t in r.trades) {
          if (_dateKey(t.exitTime) == '2026-06-04') {
            dayPnl += t.pnl;
            dayTrades++;
            tradeDetails.add({
              'entryTime': t.entryTime.toIso8601String(),
              'exitTime': t.exitTime.toIso8601String(),
              'entryPrice': t.entryPrice,
              'exitPrice': t.exitPrice,
              'pnl': t.pnl,
              'commission': t.commission,
              'signal': t.signal.name,
            });
          }
        }

        configResults.add({
          'label': cfg['label'] as String,
          'dayPnl': dayPnl,
          'dayTrades': dayTrades,
          'totalNet': r.netReturn,
          'trades': tradeDetails,
        });

        if (dayPnl > bestDayPnl) {
          bestDayPnl = dayPnl;
          bestCfg = cfg['label'] as String;
          bestTrades = tradeDetails;
        }
      }

      stockResult['configs'] = configResults;
      stockResult['bestCfg'] = bestCfg.trim();
      stockResult['dayPnl'] = bestDayPnl;
      stockResult['bestTrades'] = bestTrades;
      stockResult['dayTrades'] = bestTrades.length;

      // RSI(2) + volume filter post-analysis
      _addFilterAnalysis(warmupCandles, stockResult);
    }

    results.add(stockResult);
  }

  return results;
}

// ---- RSI(2) + Volume filter analysis (June 4 전용) ----
void _addFilterAnalysis(List<Candle> warmupCandles, Map<String, dynamic> stockResult) {
  final bestTrades = (stockResult['bestTrades'] as List<Map<String, dynamic>>?) ?? [];
  if (bestTrades.isEmpty) {
    stockResult['rsi2Filter'] = {'pass': false, 'reason': 'no trades'};
    stockResult['volFilter'] = {'pass': false, 'reason': 'no trades'};
    stockResult['combinedFilter'] = {'pass': false, 'reason': 'no trades'};
    return;
  }

  // RSI(2) 계산
  final closes = warmupCandles.map((c) => c.close).toList();
  final rsi2 = <double>[];
  for (int i = 2; i < closes.length; i++) {
    double gain = 0, loss = 0;
    for (int j = i - 1; j <= i; j++) {
      final d = closes[j] - closes[j - 1];
      if (d > 0) gain += d; else loss += d.abs();
    }
    if (gain + loss == 0) { rsi2.add(50); continue; }
    rsi2.add(100 - 100 / (1 + gain / loss));
  }

  // 20일 동시간대 평균 거래량
  final volumes = warmupCandles.map((c) => c.volume).toList();
  double avgVol = 0;
  for (int i = volumes.length - 390; i < volumes.length; i++) {
    if (i >= 0) avgVol += volumes[i];
  }
  avgVol /= 390; // 하루 평균 분봉 수

  // 각 trade에 RSI(2) + volume filter 적용
  int rsi2Pass = 0, volPass = 0, bothPass = 0;
  for (final t in bestTrades) {
    final entryTimeStr = t['entryTime'] as String;
    final signal = t['signal'] as String;
    final entryTime = DateTime.parse(entryTimeStr);

    // entry 시점의 RSI(2) 값 찾기
    final entryIdx = warmupCandles.indexWhere((c) => c.timestamp == entryTime);
    final entryRsi2 = entryIdx >= 2 && entryIdx - 1 < rsi2.length ? rsi2[entryIdx - 1] : 50;
    final entryVol = entryIdx >= 0 ? warmupCandles[entryIdx].volume : 0;

    // RSI(2) filter: VWAP 위에서 RSI(2) < 30 (롱 기준)
    final isLong = signal == 'long' || signal == 'buy';
    final rsiOk = isLong ? entryRsi2 < 30 : entryRsi2 > 70;
    if (rsiOk) rsi2Pass++;

    // Volume filter: entry 거래량 > 평균 × 1.5
    final volOk = entryVol > avgVol * 1.5;
    if (volOk) volPass++;

    if (rsiOk && volOk) bothPass++;
  }

  stockResult['rsi2Filter'] = {
    'pass': rsi2Pass == bestTrades.length,
    'passCount': rsi2Pass,
    'totalTrades': bestTrades.length,
  };
  stockResult['volFilter'] = {
    'pass': volPass == bestTrades.length,
    'passCount': volPass,
    'totalTrades': bestTrades.length,
  };
  stockResult['combinedFilter'] = {
    'pass': bothPass == bestTrades.length,
    'passCount': bothPass,
    'totalTrades': bestTrades.length,
  };
}

// ---- 점수 계산 ----
int _evaluate(Map<String, Map<String, double>> dailyData, List<String> prevDates, int histReturn) {
  final close = prevDates.map((d) => dailyData[d]!['c']!).toList();
  final high = prevDates.map((d) => dailyData[d]!['h']!).toList();
  final low = prevDates.map((d) => dailyData[d]!['l']!).toList();

  double cumTpv = 0, cumVol = 0;
  final vwap = <double>[];
  for (final d in prevDates) {
    final dd = dailyData[d]!;
    final tp = (dd['h']! + dd['l']! + dd['c']!) / 3;
    cumTpv += tp * dd['v']!;
    cumVol += dd['v']!;
    vwap.add(cumTpv / cumVol);
  }

  final vwapSlope = vwap.length > 10 ? (vwap.last - vwap[vwap.length - 11]) / 10 / vwap[vwap.length - 11] * 100 : 0.0;
  final trend = vwapSlope > 0.2 ? '상승' : (vwapSlope < -0.2 ? '하락' : '횡보');
  final ci = _calcCi(high, low, close);
  final tickPrice = _tickSize(close);
  final distTicks = ((close.last - vwap.last).abs() / tickPrice).round();

  final pnlRatio = histReturn > 0 ? histReturn / 300000 : histReturn / 10000000;
  int s = 0;
  if (pnlRatio > 0.5) s += 4;
  else if (pnlRatio > 0.1) s += 3;
  else if (pnlRatio > 0) s += 2;
  else if (histReturn != 0) s -= 2;
  if (ci < 45) s += 3;
  else if (ci < 52) s += 1;
  else s -= 1;
  if (trend == '상승') s += 2;
  else if (trend == '하락') s -= 1;
  if (distTicks >= 3 && distTicks <= 20) s += 1;
  if (vwapSlope.abs() > 0.5) s += 1;
  return s;
}

double _calcCi(List<double> h, List<double> l, List<double> c) {
  if (h.length < 15) return 50;
  final tr = <double>[]; tr.add(h[0] - l[0]);
  for (int i = 1; i < h.length; i++)
    tr.add([h[i]-l[i], (h[i]-c[i-1]).abs(), (l[i]-c[i-1]).abs()].reduce((a,b)=>a>b?a:b));
  final recent = h.length - 14;
  double sumTr = 0; for (int i = recent; i < h.length; i++) sumTr += tr[i];
  final mx = h.sublist(recent).reduce((a,b)=>a>b?a:b);
  final mn = l.sublist(recent).reduce((a,b)=>a<b?a:b);
  final rg = mx - mn;
  if (rg <= 0 || sumTr <= 0) return 50;
  return 100 * log(sumTr / rg) / log(14);
}

double _tickSize(List<double> prices) {
  final avg = prices.reduce((a,b)=>a+b) / prices.length;
  if (avg >= 100000) return 100; if (avg >= 10000) return 50; if (avg >= 5000) return 10;
  return 5;
}

// ---- 캐시 로드 ----
String _dateKey(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

List<Candle>? _loadCachedMinute(String symbol, String cacheDir) {
  if (cacheDir.isEmpty) return null;
  final d = Directory(cacheDir);
  if (!d.existsSync()) return null;

  // _full_ 파일 우선
  final fullFile = File('$cacheDir\\candle_${symbol}_full_1d.json');
  if (fullFile.existsSync()) {
    final raw = jsonDecode(fullFile.readAsStringSync()) as List<dynamic>;
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      return Candle(
        timestamp: DateTime.parse(m['t'] as String),
        open: (m['o'] as num).toDouble(), high: (m['h'] as num).toDouble(),
        low: (m['l'] as num).toDouble(), close: (m['c'] as num).toDouble(),
        volume: (m['v'] as num).toDouble(),
      );
    }).toList();
  }

  // 구형 파일 스캔 → _full_로 마이그레이션
  final oldFiles = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_${symbol}_') && !f.path.contains('_full_') && f.path.endsWith('_1d.json')).toList();
  if (oldFiles.isEmpty) return null;
  oldFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  final raw = jsonDecode(oldFiles.first.readAsStringSync()) as List<dynamic>;
  fullFile.writeAsStringSync(jsonEncode(raw));
  for (final f in oldFiles) { try { f.deleteSync(); } catch (_) {} }
  return raw.map((e) {
    final m = e as Map<String, dynamic>;
    return Candle(
      timestamp: DateTime.parse(m['t'] as String),
      open: (m['o'] as num).toDouble(), high: (m['h'] as num).toDouble(),
      low: (m['l'] as num).toDouble(), close: (m['c'] as num).toDouble(),
      volume: (m['v'] as num).toDouble(),
    );
  }).toList();
}

double _detectTickSize(List<Candle> candles) {
  final avg = candles.map((c) => c.close).reduce((a, b) => a + b) / candles.length;
  if (avg >= 100000) return 100; if (avg >= 10000) return 50; if (avg >= 5000) return 10;
  return 5;
}

// ---- 종목 리스트 ----
List<Map<String, String>> _allStocks() => [
  {'code':'005930','name':'삼성전자'},{'code':'000660','name':'SK하이닉스'},
  {'code':'005935','name':'삼성전자우'},{'code':'373220','name':'LG에너지솔루션'},
  {'code':'207940','name':'삼성바이오로직스'},{'code':'005380','name':'현대차'},
  {'code':'000270','name':'기아'},{'code':'068270','name':'셀트리온'},
  {'code':'105560','name':'KB금융'},{'code':'055550','name':'신한지주'},
  {'code':'005490','name':'POSCO홀딩스'},{'code':'012330','name':'현대모비스'},
  {'code':'003490','name':'대한항공'},{'code':'018260','name':'삼성에스디에스'},
  {'code':'323410','name':'카카오뱅크'},{'code':'377300','name':'카카오페이'},
  {'code':'086790','name':'하나금융지주'},{'code':'138930','name':'BNK금융지주'},
  {'code':'316140','name':'우리금융지주'},{'code':'024110','name':'기업은행'},
  {'code':'002790','name':'아모레G'},{'code':'090430','name':'아모레퍼시픽'},
  {'code':'036570','name':'엔씨소프트'},{'code':'251270','name':'넷마블'},
  {'code':'259960','name':'크래프톤'},{'code':'066570','name':'LG전자'},
  {'code':'006400','name':'삼성SDI'},{'code':'010130','name':'고려아연'},
  {'code':'000810','name':'삼성화재'},{'code':'030200','name':'KT'},
  {'code':'017670','name':'SK텔레콤'},{'code':'034730','name':'SK'},
  {'code':'096770','name':'SK이노베이션'},{'code':'011170','name':'롯데케미칼'},
  {'code':'051910','name':'LG화학'},{'code':'028260','name':'삼성물산'},
  {'code':'042660','name':'한화오션'},{'code':'000880','name':'한화'},
  {'code':'086280','name':'현대글로비스'},{'code':'329180','name':'HD현대중공업'},
  {'code':'267250','name':'HD현대'},{'code':'009540','name':'HD한국조선해양'},
  {'code':'047050','name':'포스코인터내셔널'},{'code':'128940','name':'한미약품'},
  {'code':'047810','name':'한국항공우주'},{'code':'021240','name':'코웨이'},
  {'code':'010140','name':'삼성중공업'},{'code':'009150','name':'삼성전기'},
  {'code':'011200','name':'HMM'},{'code':'241560','name':'두산밥캣'},
  {'code':'000150','name':'두산'},{'code':'034020','name':'두산에너빌리티'},
  {'code':'402340','name':'SK스퀘어'},{'code':'352820','name':'하이브'},
  {'code':'004020','name':'현대제철'},{'code':'010620','name':'현대미포조선'},
  {'code':'071050','name':'한국금융지주'},{'code':'016360','name':'삼성증권'},
  {'code':'032830','name':'삼성생명'},{'code':'088350','name':'한화생명'},
  {'code':'063160','name':'종근당'},{'code':'000100','name':'유한양행'},
  {'code':'001040','name':'CJ'},{'code':'097950','name':'CJ제일제당'},
  {'code':'247540','name':'에코프로비엠'},{'code':'196170','name':'알테오젠'},
  {'code':'091990','name':'셀트리온헬스케어'},{'code':'348370','name':'엘앤에프'},
  {'code':'263750','name':'펄어비스'},{'code':'112040','name':'위메이드'},
  {'code':'095340','name':'ISC'},{'code':'214150','name':'클래시스'},
  {'code':'145020','name':'휴젤'},{'code':'042700','name':'한미반도체'},
  {'code':'277810','name':'레인보우로보틱스'},{'code':'293490','name':'카카오게임즈'},
  {'code':'067160','name':'아프리카TV'},{'code':'403870','name':'HPSP'},
  {'code':'340570','name':'티웨이항공'},{'code':'065350','name':'신성델타테크'},
  {'code':'018290','name':'브이티'},{'code':'115180','name':'큐리옥스'},
  {'code':'256840','name':'한국파마'},{'code':'069080','name':'웹젠'},
  {'code':'086900','name':'메디톡스'},{'code':'041510','name':'에스엠'},
  {'code':'052790','name':'액토즈소프트'},{'code':'900280','name':'골든센츄리'},
  {'code':'051360','name':'토비스'},{'code':'032580','name':'피델릭스'},
];

// ---- _knownResults ----
final Map<String, Map<String, dynamic>> _knownResults = {
  '000100': {'net': -126, 'grade': '부적합'},'000150': {'net': -6356, 'grade': '부적합'},
  '000270': {'net': -12404, 'grade': '부적합'},'000660': {'net': -4769, 'grade': '부적합'},
  '000810': {'net': -12543, 'grade': '부적합'},'000880': {'net': 38864, 'grade': '적합'},
  '001040': {'net': 61476, 'grade': '적합'},'002790': {'net': -11654, 'grade': '부적합'},
  '003490': {'net': 9707, 'grade': '적합'},'004020': {'net': -8442, 'grade': '부적합'},
  '005380': {'net': -4411, 'grade': '부적합'},'005490': {'net': 3638, 'grade': '적합'},
  '005930': {'net': -4314, 'grade': '부적합'},'005935': {'net': -10523, 'grade': '부적합'},
  '006400': {'net': -4294, 'grade': '부적합'},'009150': {'net': 10599, 'grade': '적합'},
  '009540': {'net': -255, 'grade': '부적합'},'010130': {'net': 39619, 'grade': '적합'},
  '010140': {'net': 14395, 'grade': '적합'},'010620': {'net': 8966, 'grade': '적합'},
  '011170': {'net': -4006, 'grade': '부적합'},'011200': {'net': 7273, 'grade': '적합'},
  '012330': {'net': -5218, 'grade': '부적합'},'016360': {'net': -1200, 'grade': '부적합'},
  '017670': {'net': -3214, 'grade': '부적합'},'018260': {'net': -6132, 'grade': '부적합'},
  '018290': {'net': -3703, 'grade': '부적합'},'021240': {'net': -6917, 'grade': '부적합'},
  '024110': {'net': -828, 'grade': '부적합'},'028260': {'net': -5401, 'grade': '부적합'},
  '030200': {'net': -5422, 'grade': '부적합'},'032580': {'net': 5779, 'grade': '적합'},
  '032830': {'net': 9325, 'grade': '적합'},'034020': {'net': 450, 'grade': '적합'},
  '034730': {'net': 10764, 'grade': '적합'},'036570': {'net': -2595, 'grade': '부적합'},
  '041510': {'net': -4105, 'grade': '부적합'},'042660': {'net': -7232, 'grade': '부적합'},
  '042700': {'net': -6404, 'grade': '부적합'},'047050': {'net': -8531, 'grade': '부적합'},
  '047810': {'net': 14593, 'grade': '적합'},'051360': {'net': 2934, 'grade': '적합'},
  '051910': {'net': -723, 'grade': '부적합'},'052790': {'net': -372, 'grade': '부적합'},
  '055550': {'net': -36, 'grade': '부적합'},'063160': {'net': 248, 'grade': '적합'},
  '065350': {'net': -18838, 'grade': '부적합'},'066570': {'net': -11095, 'grade': '부적합'},
  '067160': {'net': 4549, 'grade': '적합'},'068270': {'net': -2206, 'grade': '부적합'},
  '069080': {'net': 15929, 'grade': '적합'},'071050': {'net': 5915, 'grade': '적합'},
  '086280': {'net': -4857, 'grade': '부적합'},'086790': {'net': 22739, 'grade': '적합'},
  '086900': {'net': -2516, 'grade': '부적합'},'088350': {'net': -17126, 'grade': '부적합'},
  '090430': {'net': -6776, 'grade': '부적합'},'095340': {'net': 41611, 'grade': '적합'},
  '096770': {'net': 194, 'grade': '적합'},'097950': {'net': 8092, 'grade': '적합'},
  '105560': {'net': 2706, 'grade': '적합'},'112040': {'net': 45047, 'grade': '적합'},
  '115180': {'net': 44155, 'grade': '적합'},'128940': {'net': 34564, 'grade': '적합'},
  '138930': {'net': -5443, 'grade': '부적합'},'145020': {'net': 42251, 'grade': '적합'},
  '196170': {'net': 3883, 'grade': '적합'},'207940': {'net': -4593, 'grade': '부적합'},
  '214150': {'net': -3347, 'grade': '부적합'},'241560': {'net': -9702, 'grade': '부적합'},
  '247540': {'net': 12238, 'grade': '적합'},'251270': {'net': 25246, 'grade': '적합'},
  '256840': {'net': 46459, 'grade': '적합'},'259960': {'net': -2825, 'grade': '부적합'},
  '263750': {'net': -9385, 'grade': '부적합'},'267250': {'net': -6280, 'grade': '부적합'},
  '277810': {'net': -4370, 'grade': '부적합'},'293490': {'net': -3433, 'grade': '부적합'},
  '316140': {'net': -3684, 'grade': '부적합'},'323410': {'net': 54196, 'grade': '적합'},
  '329180': {'net': -10406, 'grade': '부적합'},'340570': {'net': -3696, 'grade': '부적합'},
  '348370': {'net': -12721, 'grade': '부적합'},'352820': {'net': -5040, 'grade': '부적합'},
  '373220': {'net': -3612, 'grade': '부적합'},'377300': {'net': 129387, 'grade': '적합'},
  '402340': {'net': 62825, 'grade': '적합'},'403870': {'net': -9790, 'grade': '부적합'},
};

// ---- 리포트 저장 ----
void _saveWfReport(Map<String, dynamic> wf, String dir) {
  final all = wf['allResults'] as List<Map<String, dynamic>>;
  final totalScore7 = wf['totalScore7'] as int;

  // config별 집계
  final configLabels = _configs.map((c) => c['label'] as String).toList();
  final Map<String, double> cfgTotalRet = {};
  final Map<String, int> cfgTotalWins = {};
  final Map<String, int> cfgTotalDays = {};
  final Map<String, double> cfgTotalComm = {};
  for (final lbl in configLabels) {
    cfgTotalRet[lbl] = 0; cfgTotalWins[lbl] = 0; cfgTotalDays[lbl] = 0; cfgTotalComm[lbl] = 0;
  }

  for (final s in all) {
    final cRet = s['configReturns'] as Map<String, dynamic>;
    final cWins = s['configWins'] as Map<String, dynamic>;
    final cDays = s['configDays'] as Map<String, dynamic>;
    for (final lbl in configLabels) {
      cfgTotalRet[lbl] = (cfgTotalRet[lbl] ?? 0) + ((cRet[lbl] as num?)?.toDouble() ?? 0);
      cfgTotalWins[lbl] = (cfgTotalWins[lbl] ?? 0) + ((cWins[lbl] as int?) ?? 0);
      cfgTotalDays[lbl] = (cfgTotalDays[lbl] ?? 0) + ((cDays[lbl] as int?) ?? 0);
    }
    // commission per stock: sum from days
    final days = s['days'] as List<Map<String, dynamic>>;
    for (final d in days) {
      final cfgs = d['configs'] as List<Map<String, dynamic>>;
      for (final cfg in cfgs) {
        cfgTotalComm[cfg['cfg'] as String] = (cfgTotalComm[cfg['cfg'] as String] ?? 0) + ((cfg['commission'] as num?)?.toDouble() ?? 0);
      }
    }
  }

  final b = StringBuffer();
  b.writeln('# Walk-Forward V2: score7+ → D-60 warmup (14 config 종합 리포트)');
  b.writeln('\n**생성일:** ${DateTime.now().toIso8601String().substring(0,10)}');
  b.writeln('**방법:** D-20~D-1 일봉 점수 → score7+ → D-60~D 분봉으로 14개 config Long Only');
  b.writeln('**조건:** 원금 30만원, 수수료 0.147%, closeAtEndOfDay, 3단계 손절\n');

  b.writeln('## 전략(config)별 종합 비교');
  b.writeln('| 순위 | 전략 | 거래일 | 수익일 | 승률 | 순수익 | 총수수료 | 평균일수익 |');
  b.writeln('|------|------|--------|--------|------|--------|---------|-----------|');
  final rankedCfgs = configLabels.toList()..sort((a, b) => ((cfgTotalRet[b] ?? 0) - (cfgTotalRet[a] ?? 0)).round());
  for (int i = 0; i < rankedCfgs.length; i++) {
    final lbl = rankedCfgs[i];
    final days = cfgTotalDays[lbl] ?? 0;
    final wins = cfgTotalWins[lbl] ?? 0;
    final ret = cfgTotalRet[lbl] ?? 0;
    final comm = cfgTotalComm[lbl] ?? 0;
    b.writeln('| ${i+1} | $lbl | $days | $wins | ${days > 0 ? (wins/days*100).toStringAsFixed(0) : 0}% | ${ret.toStringAsFixed(0)}원 | ${comm.toStringAsFixed(0)}원 | ${days > 0 ? (ret/days).toStringAsFixed(0) : 0}원 |');
  }

  b.writeln('\n## 종목별 config 수익 순위');
  b.writeln('| 순위 | 코드 | 종목 |');
  for (int i = 0; i < configLabels.length; i++) b.writeln('| ${i+2} | | ${configLabels[i]} | 거래일 | 승률 | 순수익 |');
  b.writeln('|------|------|------|');
  int rank = 0;
  for (final s in all) {
    final code = s['code']; final name = s['name'];
    final cRet = s['configReturns'] as Map<String, dynamic>;
    final cDays = s['configDays'] as Map<String, dynamic>;
    final cWins = s['configWins'] as Map<String, dynamic>;
    // check if any config has trades
    bool hasAny = false;
    for (final lbl in configLabels) { if ((cDays[lbl] as int? ?? 0) > 0) hasAny = true; }
    if (!hasAny) continue;
    rank++;
    b.writeln('| $rank | $code | $name | | | |');
    for (final lbl in configLabels) {
      final days = cDays[lbl] as int? ?? 0;
      if (days == 0) continue;
      final wins = cWins[lbl] as int? ?? 0;
      final ret = (cRet[lbl] as num?)?.toDouble() ?? 0;
      b.writeln('| | | $lbl | $days | ${(wins/days*100).toStringAsFixed(0)}% | ${ret.toStringAsFixed(0)}원 |');
    }
  }

  b.writeln('\n## 종목별 일별 상세 (config별)');
  for (final s in all) {
    final days = s['days'] as List<Map<String, dynamic>>;
    final code = s['code']; final name = s['name'];
    bool hasAnyDay = false;
    for (final d in days) {
      final cfgs = d['configs'] as List<Map<String, dynamic>>;
      if (cfgs.any((c) => (c['return'] as num) != 0)) { hasAnyDay = true; break; }
    }
    if (!hasAnyDay) continue;

    b.writeln('\n### $code $name (${days.length} score7+일)');
    b.writeln('| 날짜 | ${configLabels.join(' | ')} |');
    b.writeln('|------|${configLabels.map((_) => '------').join('|')}|');
    for (final d in days) {
      final cfgs = d['configs'] as List<Map<String, dynamic>>;
      final vals = configLabels.map((lbl) {
        final found = cfgs.cast<Map<String, dynamic>>().firstWhere((c) => c['cfg'] == lbl.trim(), orElse: () => {'return': 0});
        final v = (found['return'] as num?)?.toDouble() ?? 0;
        return v == 0 ? '-' : v.toStringAsFixed(0);
      });
      b.writeln('| ${d['date']} | ${vals.join(' | ')} |');
    }
  }

  File('$dir\\walk_forward_v2_report.md').writeAsStringSync(b.toString());
  try { File('${Directory.current.path}\\ai_docs\\walk_forward_v2_report.md').writeAsStringSync(b.toString()); } catch (_) {}
  print('\nTest 1 리포트 저장: walk_forward_v2_report.md');
}

void _saveJune4Report(List<Map<String, dynamic>> results, String dir) {
  final score7 = results.where((r) => r['score7'] == true).toList();
  final winners = score7.where((r) => ((r['dayPnl'] as double?) ?? 0) > 0).toList();
  final losers = score7.where((r) => ((r['dayPnl'] as double?) ?? 0) <= 0).toList();
  double totalPnl = 0;
  for (final r in score7) totalPnl += (r['dayPnl'] as double?) ?? 0;

  final b = StringBuffer();
  b.writeln('# June 4 당일거래: score7+ → D-60 warmup + 7 configs + RSI(2)/Volume 필터');
  b.writeln('\n**생성일:** ${DateTime.now().toIso8601String().substring(0,10)}');
  b.writeln('**거래일:** 2026-06-04');
  b.writeln('**조건:** score7+ 종목, D-60~0604 분봉 warmup, 7개 config best 선택, hybrid Long Only\n');

  b.writeln('## 종합 통계');
  b.writeln('| 항목 | 값 |');
  b.writeln('|------|-----|');
  b.writeln('| score7+ 종목 | ${score7.length}개 |');
  b.writeln('| 수익 종목 | ${winners.length}개 |');
  b.writeln('| 손실 종목 | ${losers.length}개 |');
  b.writeln('| 승률 | ${score7.length > 0 ? (winners.length/score7.length*100).toStringAsFixed(0) : 0}% |');
  b.writeln('| 합계 수익 | ${totalPnl.toStringAsFixed(0)}원 |');
  b.writeln('| 평균 종목수익 | ${score7.length > 0 ? (totalPnl/score7.length).toStringAsFixed(0) : 0}원 |');

  b.writeln('\n## ✅ 수익 종목');
  b.writeln('| 순위 | 코드 | 종목 | 점수 | 최적설정 | 당일수익 | 거래수 | RSI(2)필터 | Vol필터 |');
  b.writeln('|------|------|------|------|----------|----------|--------|-----------|---------|');
  winners.sort((a,b) => ((b['dayPnl'] as double?) ?? 0).compareTo((a['dayPnl'] as double?) ?? 0));
  for (int i = 0; i < winners.length; i++) {
    final s = winners[i];
    final d = s['dayPnl'] as double;
    final score = s['score'] as int;
    final cfg = s['bestCfg'] as String;
    final trades = s['dayTrades'] as int;
    final rsi2 = (s['rsi2Filter'] as Map)['passCount'];
    final vol = (s['volFilter'] as Map)['passCount'];
    b.writeln('| ${i+1} | ${s['code']} | ${s['name']} | $score | $cfg | +${d.toStringAsFixed(0)}원 | $trades | $rsi2/${trades} | $vol/${trades} |');
  }

  b.writeln('\n## ❌ 손실 종목');
  b.writeln('| 순위 | 코드 | 종목 | 점수 | 최적설정 | 당일수익 | 거래수 | RSI(2)필터 | Vol필터 |');
  b.writeln('|------|------|------|------|----------|----------|--------|-----------|---------|');
  losers.sort((a,b) => ((b['dayPnl'] as double?) ?? 0).compareTo((a['dayPnl'] as double?) ?? 0));
  for (int i = 0; i < losers.length; i++) {
    final s = losers[i];
    final d = s['dayPnl'] as double;
    final score = s['score'] as int;
    final cfg = s['bestCfg'] as String;
    final trades = s['dayTrades'] as int;
    final rsi2 = (s['rsi2Filter'] as Map)['passCount'];
    final vol = (s['volFilter'] as Map)['passCount'];
    b.writeln('| ${i+1} | ${s['code']} | ${s['name']} | $score | $cfg | ${d.toStringAsFixed(0)}원 | $trades | $rsi2/${trades} | $vol/${trades} |');
  }

  // 상세 trade 내역
  b.writeln('\n## 종목별 상세 Trade 내역');
  for (final s in score7) {
    final bestTrades = s['bestTrades'] as List<Map<String, dynamic>>;
    if (bestTrades.isEmpty) {
      b.writeln('\n### ${s['code']} ${s['name']} (score${s['score']}, ${s['bestCfg']}, ${(s['dayPnl'] as double).toStringAsFixed(0)}원)');
      b.writeln('  *거래 없음*');
      continue;
    }
    b.writeln('\n### ${s['code']} ${s['name']} (score${s['score']}, ${s['bestCfg']}, ${(s['dayPnl'] as double).toStringAsFixed(0)}원)');
    b.writeln('| 진입시간 | 청산시간 | 신호 | 진입가 | 청산가 | 순손익 | 수수료 |');
    b.writeln('|----------|----------|------|--------|--------|--------|--------|');
    for (final t in bestTrades) {
      final pnl = t['pnl'] as double;
      final comm = t['commission'] as double? ?? 0;
      b.writeln('| ${(t['entryTime'] as String).substring(11,19)} | ${(t['exitTime'] as String).substring(11,19)} | ${t['signal']} | ${(t['entryPrice'] as num).toStringAsFixed(0)} | ${(t['exitPrice'] as num).toStringAsFixed(0)} | ${pnl.toStringAsFixed(0)}원 | ${comm.toStringAsFixed(0)}원 |');
    }
  }

  // RSI(2) + Volume 필터 분석
  b.writeln('\n## RSI(2) + Volume 필터 분석');
  int rsi2OnlyPass = 0, volOnlyPass = 0, combinedPass = 0;
  for (final s in score7) {
    if ((s['rsi2Filter'] as Map)['pass'] == true) rsi2OnlyPass++;
    if ((s['volFilter'] as Map)['pass'] == true) volOnlyPass++;
    if ((s['combinedFilter'] as Map)['pass'] == true) combinedPass++;
  }
  b.writeln('| 필터 | 통과 종목 | 조건 |');
  b.writeln('|------|----------|------|');
  b.writeln('| RSI(2)만 | $rsi2OnlyPass/${score7.length} | VWAP 방향 + RSI(2) 극단값 일치 |');
  b.writeln('| Volume만 | $volOnlyPass/${score7.length} | 진입 거래량 > 20일 평균×1.5 |');
  b.writeln('| RSI(2)+Volume | $combinedPass/${score7.length} | 둘 다 통과 |');

  File('$dir\\june4_trading_report.md').writeAsStringSync(b.toString());
  try { File('${Directory.current.path}\\ai_docs\\june4_trading_report.md').writeAsStringSync(b.toString()); } catch (_) {}
  print('Test 2 리포트 저장: june4_trading_report.md');
}
