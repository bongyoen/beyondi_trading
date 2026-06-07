import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/stock_search/data/stock_db.dart';

/// 캐시된 88종목 → 일봉 분석 → vwap_poc 적합도 스코어링 → Top 10 저장
void main(List<String> args) async {
  final cacheDir =
      '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';

  // 종목명 맵
  final nameMap = <String, String>{};
  for (final s in stockDb) {
    nameMap[s.code] = s.name;
  }

  // 캐시된 분봉 데이터에서 종목 코드 추출
  print('>>> 캐시된 종목 스캔 중...');
  final files = Directory(cacheDir).listSync().whereType<File>()
      .where((f) => f.path.endsWith('_full_1d.json'))
      .toList();
  print('>>> ${files.length}개 캐시 파일 발견\n');

  // 3. 종목별 캔들 분석 + 스코어링
  final results = <Map<String, dynamic>>[];

  for (int i = 0; i < files.length; i++) {
    final name = files[i].path.split('\\').last;
    final match = RegExp(r'candle_(\d{6})_').firstMatch(name);
    if (match == null) continue;
    final code = match.group(1)!;

    print('[$i/${files.length}] $code');

    // 분봉 데이터를 일봉으로 집계
    List<Candle> dailyCandles;
    try {
      final raw = jsonDecode(files[i].readAsStringSync()) as List<dynamic>;
      final minuteCandles = raw.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
      dailyCandles = _aggregateDaily(minuteCandles);
    } catch (e) {
      print('  SKIP: 데이터 로드 실패');
      continue;
    }
    if (dailyCandles.length < 10) {
      print('  SKIP: 일봉 데이터 부족 (${dailyCandles.length}봉)');
      continue;
    }

    dailyCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // VWAP 계산 (일봉 기준 cumulative)
    final vwapSeries = _calcVwap(dailyCandles);
    final vwap = vwapSeries.last;
    final closes = dailyCandles.map((c) => c.close).toList();
    final avgPrice =
        closes.reduce((a, b) => a + b) / closes.length;
    final lastClose = dailyCandles.last.close;
    final tickSize = _tickSize(avgPrice);

    // POC (Volume Profile): 가장 거래량 많은 가격대
    final poc = _calcPoc(dailyCandles);
    // VWAP과 POC 거리
    final pocDist = poc > 0 ? (lastClose - poc).abs() / tickSize : 0.0;

    // CI(14)
    final ci = _calcCi(dailyCandles);

    // VWAP slope (최근 5일)
    final vwapSlope = vwapSeries.length >= 5
        ? (vwapSeries.last - vwapSeries[vwapSeries.length - 5]) / 5
        : 0.0;

    // VWAP 이탈 거리 (틱)
    final vwapDist = (lastClose - vwap).abs() / tickSize;

    // 20일 수익률
    final periodReturn =
        closes.length > 1 ? (closes.last - closes.first) / closes.first * 100 : 0.0;

    // ATR 비율 (최근 5일 / 전체)
    final atr5 = _calcAtr(dailyCandles, 5);
    final atr20 = _calcAtr(dailyCandles, closes.length > 20 ? 20 : closes.length);
    final atrRatio = atr20 > 0 ? atr5 / atr20 : 1.0;

    // 스코어링 (0~10)
    int score = 0;
    // CI < 50 = 횡보장 → vwap_poc에 유리
    if (ci < 50) score += 3;
    else if (ci >= 52) score -= 1;
    // VWAP 이탈 3~20틱 (적정 범위)
    if (vwapDist >= 3 && vwapDist <= 20) score += 2;
    // 20일 수익률 > 0 (longOnly 우대)
    if (periodReturn > 0) score += 2;
    // VWAP 상승 추세
    if (vwapSlope > 0) score += 2;
    // 최근 변동성 유지
    if (atrRatio >= 0.8) score += 1;

    final stockName = nameMap[code] ?? code;

    results.add({
      'code': code,
      'name': stockName,
      'score': score,
      'ci': ci,
      'vwapDist': vwapDist,
      'vwapSlope': vwapSlope,
      'periodReturn': periodReturn,
      'atrRatio': atrRatio,
      'pocDist': pocDist,
      'close': lastClose,
      'vwap': vwap,
    });

    await Future.delayed(const Duration(milliseconds: 150));
  }

  // 5. 정렬 + Top 10
  results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  final top10 = results.take(10).toList();

  // 6. 저장
  File('$cacheDir\\vwap_poc_top10.json')
      .writeAsStringSync(jsonEncode(top10));
  print('\n>>> vwap_poc_top10.json 저장 완료');

  // 7. 출력
  print('\n${'=' * 65}');
  print('  VWAP+POC 추천 TOP 10');
  print('${'=' * 65}');
  print('순위 종목    종목명        점수  CI   VWAP거리  20일수익률 추세');
  print('${'-' * 65}');
  for (int i = 0; i < top10.length; i++) {
    final e = top10[i];
    final rank = '${i + 1}'.padLeft(2);
    final codeS = (e['code'] as String).padLeft(6);
    final nameS = ((e['name'] as String)).padRight(10);
    final scoreS = '${e['score']}/10'.padLeft(5);
    final ciS = (e['ci'] as num).toStringAsFixed(1).padLeft(5);
    final distS = (e['vwapDist'] as num).toStringAsFixed(0).padLeft(5);
    final ret = (e['periodReturn'] as num).toDouble();
    final retS = '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}%'.padLeft(8);
    final trend =
        (e['vwapSlope'] as num) > 0 ? '상승' : (e['vwapSlope'] as num) < 0 ? '하락' : '횡보';
    print('  $rank  $codeS $nameS $scoreS $ciS  ${distS}틱 $retS  $trend');
  }
  print('${'=' * 65}');
  print('\n앱 대시보드에서 확인하려면 앱을 재시작하세요.');
}

List<double> _calcVwap(List<Candle> candles) {
  final vwap = <double>[];
  double tpv = 0, vol = 0;
  for (final c in candles) {
    final tp = (c.high + c.low + c.close) / 3;
    tpv += tp * c.volume;
    vol += c.volume;
    vwap.add(vol > 0 ? tpv / vol : c.close);
  }
  return vwap;
}

double _calcPoc(List<Candle> candles) {
  if (candles.isEmpty) return 0;
  // 틱 사이즈 기반 가격대별 볼륨 집계
  final avg = candles.map((c) => c.close).reduce((a, b) => a + b) / candles.length;
  final ts = _tickSize(avg);
  if (ts <= 0) return candles.last.close;
  final buckets = <String, double>{};
  for (final c in candles) {
    final bucket = (c.close / ts).roundToDouble() * ts;
    buckets[bucket.toString()] =
        (buckets[bucket.toString()] ?? 0) + c.volume;
  }
  String maxB = '';
  double maxV = 0;
  for (final e in buckets.entries) {
    if (e.value > maxV) { maxV = e.value; maxB = e.key; }
  }
  return double.tryParse(maxB) ?? candles.last.close;
}

double _calcCi(List<Candle> candles, {int period = 14}) {
  if (candles.length < period + 1) return 50;
  final tr = <double>[];
  tr.add(candles[0].high - candles[0].low);
  for (int i = 1; i < candles.length; i++) {
    final hl = candles[i].high - candles[i].low;
    final hc = (candles[i].high - candles[i - 1].close).abs();
    final lc = (candles[i].low - candles[i - 1].close).abs();
    tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
  }
  final last = candles.length - 1;
  double sumTr = 0;
  double maxH = candles[last].high;
  double minL = candles[last].low;
  for (int j = last - period + 1; j <= last; j++) {
    sumTr += tr[j];
    if (candles[j].high > maxH) maxH = candles[j].high;
    if (candles[j].low < minL) minL = candles[j].low;
  }
  final range = maxH - minL;
  if (range <= 0 || sumTr <= 0) return 50;
  return 100 * log(sumTr / range) / log(period);
}

double _calcAtr(List<Candle> candles, int period) {
  if (candles.length < 2) return 0;
  final tr = <double>[];
  tr.add(candles[0].high - candles[0].low);
  for (int i = 1; i < candles.length; i++) {
    final hl = candles[i].high - candles[i].low;
    final hc = (candles[i].high - candles[i - 1].close).abs();
    final lc = (candles[i].low - candles[i - 1].close).abs();
    tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
  }
  if (tr.length < period) return 0;
  double sum = 0;
  for (int i = tr.length - period; i < tr.length; i++) sum += tr[i];
  return sum / period;
}

double _tickSize(double avgPrice) {
  if (avgPrice >= 100000) return 100;
  if (avgPrice >= 10000) return 50;
  if (avgPrice >= 5000) return 10;
  return 5;
}

Candle _parseCandle(Map<String, dynamic> m) => Candle(
  timestamp: DateTime.parse(m['t'] as String),
  open: (m['o'] as num).toDouble(), high: (m['h'] as num).toDouble(),
  low: (m['l'] as num).toDouble(), close: (m['c'] as num).toDouble(),
  volume: (m['v'] as num).toDouble(),
);

List<Candle> _aggregateDaily(List<Candle> minuteCandles) {
  if (minuteCandles.isEmpty) return [];
  final map = <String, List<Candle>>{};
  for (final c in minuteCandles) {
    final key = '${c.timestamp.year}-${c.timestamp.month}-${c.timestamp.day}';
    map.putIfAbsent(key, () => []).add(c);
  }
  final result = <Candle>[];
  final keys = map.keys.toList()..sort();
  for (final key in keys) {
    final day = map[key]!;
    result.add(Candle(
      timestamp: day.first.timestamp,
      open: day.first.open,
      high: day.map((c) => c.high).reduce((a, b) => a > b ? a : b),
      low: day.map((c) => c.low).reduce((a, b) => a < b ? a : b),
      close: day.last.close,
      volume: day.map((c) => c.volume).reduce((a, b) => a + b),
    ));
  }
  return result;
}
