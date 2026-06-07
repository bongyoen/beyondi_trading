import 'dart:convert';
import 'dart:io';

import 'package:beyondi_trading/features/backtest/data/datasources/kis_stock_api.dart';
import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/backtest/domain/usecases/run_backtest.dart';

void main(List<String> args) async {
  final cacheDir =
      '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final doDownload = args.contains('--download');

  // 1. KIS 설정 로드
  final configFile = File('$cacheDir\\kis_config.json');
  if (!configFile.existsSync()) {
    print('kis_config.json 없음');
    exit(1);
  }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;

  // 2. KisStockApi (실전)
  final api = KisStockApi(appKey: appKey, appSecret: appSecret, isPaper: false);

  // 3. 등락률순위 API 호출
  print('>>> 등락률순위 조회 중...');
  List<Map<String, dynamic>> rankData;
  try {
    rankData = await api.fetchFluctuationRank(divCode: '000', count: 50);
  } catch (e) {
    print('등락률순위 조회 실패: $e');
    exit(1);
  }
  print('>>> ${rankData.length}개 종목 수신\n');

  // 4. 종목별 ORB 백테스트
  final results = <Map<String, dynamic>>[];

  for (int i = 0; i < rankData.length; i++) {
    final item = rankData[i];
    final code = (item['stck_shrn_iscd'] ?? '') as String;
    final name = (item['hts_kor_isnm'] ?? '') as String;
    final fluctStr = (item['prdy_vrss'] ?? '0') as String;
    final fluct = double.tryParse(fluctStr) ?? 0;
    final rank = i + 1;

    print('[$rank/${rankData.length}] $code $name');
    if (code.isEmpty) {
      print('  SKIP: 종목코드 없음');
      continue;
    }

    // 캐시 로드 + 누락일 다운로드
    var candles = await _ensureCandles(api, code, cacheDir, doDownload);
    if (candles == null || candles.length < 200) {
      print('  SKIP: 분봉 데이터 부족 (${candles?.length ?? 0}캔들)');
      continue;
    }

    final ts = _detectTickSize(candles);
    print('  ${candles.length}캔들, 틱=$ts');

    // ORB 30분 백테스트
    final r = runBacktest(
      candles: candles,
      tickSize: ts,
      takeProfitTicks: 0,
      stopLossTicks: 0,
      closeAtEndOfDay: true,
      mode: 'orb',
      orbRangeMinutes: 30,
      orbStopPercent: 0.005,
      commissionPercent: 0.147,
      principal: 300000,
      consecutiveLossLimit: 10,
      dailyLossLimit: (300000 * 0.1).clamp(30000, 1000000),
      maxTotalLoss: (300000 * 0.3).clamp(50000, 5000000),
      useAtrPositionSizing: true,
      longOnly: true,
    );

    print('  순손익: ₩${_fmt(r.netReturn)}  승률: ${(r.winRate * 100).toStringAsFixed(1)}%  거래: ${r.trades.length}');

    if (r.trades.isNotEmpty) {
      results.add({
        'rank': rank,
        'code': code,
        'name': name,
        'fluctuation': fluct,
        'netReturn': r.netReturn,
        'winRate': r.winRate,
        'trades': r.trades.length,
        'maxDrawdown': r.maxDrawdown,
        'sharpeRatio': r.sharpeRatio,
      });
    }
  }

  // 5. 순손익 기준 정렬
  results.sort((a, b) => (b['netReturn'] as num).compareTo(a['netReturn'] as num));
  final top10 = results.take(10).toList();

  // 6. 저장
  final outFile = File('$cacheDir\\orb_top10.json');
  outFile.writeAsStringSync(jsonEncode(top10));
  print('\n>>> orb_top10.json 저장 완료');

  // 7. 출력
  print('\n${'=' * 60}');
  print('  ORB 추천 TOP 10 (등락률순위 기반)');
  print('${'=' * 60}');
  print('순위  종목    종목명         등락률   ORB순손익   승률    거래');
  print('${'-' * 60}');
  for (int i = 0; i < top10.length; i++) {
    final e = top10[i];
    final rankLabel = '${i + 1}'.padLeft(2);
    final codeStr = (e['code'] as String).padRight(6);
    final nameStr = (e['name'] as String).padRight(12);
    final fluctStr = (e['fluctuation'] as num).toStringAsFixed(1).padLeft(6);
    final netStr = _fmt((e['netReturn'] as num).toDouble()).padLeft(10);
    final winStr = '${((e['winRate'] as num) * 100).toStringAsFixed(1)}%'.padLeft(6);
    final tradeStr = '${e['trades']}'.padLeft(4);
    String sign = (e['netReturn'] as num) >= 0 ? '+' : '';
    print('  $rankLabel  $codeStr $nameStr $fluctStr  $sign$netStr  $winStr  $tradeStr');
  }
  print('${'=' * 60}');
  print('\n앱 대시보드에서 확인하려면 앱을 재시작하세요.');
  api.dispose();
}

/// 분봉 캐시 로드 + 누락일 다운로드.
Future<List<Candle>?> _ensureCandles(
    KisStockApi api, String symbol, String cacheDir, bool doDownload) async {
  // 파싱 유틸
  int _d(String v, [int fallback = 0]) => int.tryParse(v) ?? fallback;

  // 캐시 파일명: candle_{symbol}_full_1d.json
  final cacheFile = File('$cacheDir\\candle_${symbol}_full_1d.json');

  List<Candle> candles = [];
  DateTime lastDate = DateTime(2000);

  if (cacheFile.existsSync()) {
    try {
      final raw = jsonDecode(cacheFile.readAsStringSync()) as List<dynamic>;
      candles = raw.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
      candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (candles.isNotEmpty) {
        lastDate = candles.last.timestamp;
      }
    } catch (_) {
      candles = [];
    }
  }

  // 오늘 날짜 (장 마감 후면 오늘도 포함)
  final today = DateTime.now();
  final todayEnd = DateTime(today.year, today.month, today.day, 15, 30);
  final lastFetchDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
  final latestTarget = today.hour >= 16 ? today : today.subtract(const Duration(days: 1));
  final targetEnd = DateTime(latestTarget.year, latestTarget.month, latestTarget.day);

  // 누락된 영업일 계산 (주말 제외)
  final missingDays = <DateTime>[];
  if (lastFetchDay.isBefore(targetEnd)) {
    var d = lastFetchDay.add(const Duration(days: 1));
    while (!d.isAfter(targetEnd)) {
      if (d.weekday != 6 && d.weekday != 7) {
        missingDays.add(DateTime(d.year, d.month, d.day));
      }
      d = d.add(const Duration(days: 1));
    }
  }

  // 다운로드
  if (missingDays.isNotEmpty && doDownload) {
    print('  누락 ${missingDays.length}일 다운로드 중...');
    for (final day in missingDays) {
      try {
        final chunk = await api.fetchMinuteCandles(symbol: symbol, date: day);
        candles.addAll(chunk);
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        print('  ${_fmtDate(day)} 조회 실패: $e');
      }
    }
    candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    // 중복 제거 (같은 timestamp)
    final seen = <DateTime>{};
    candles = candles.where((c) => seen.add(c.timestamp)).toList();
    // 저장
    cacheFile.writeAsStringSync(jsonEncode(
        candles.map((c) => _candleToJson(c)).toList()));
    print('  ${candles.length}캔들 저장 완료');
  } else if (candles.isEmpty && !doDownload) {
    return null;
  } else if (candles.isEmpty) {
    // 캐시도 없고 다운로드 모드 → 초기 10영업일 다운로드
    print('  초기 데이터 다운로드 중...');
    final start = today.subtract(const Duration(days: 14));
    for (int d = 0; d < 14; d++) {
      final day = start.add(Duration(days: d));
      if (day.weekday == 6 || day.weekday == 7) continue;
      try {
        final chunk = await api.fetchMinuteCandles(symbol: symbol, date: day);
        candles.addAll(chunk);
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        print('  ${_fmtDate(day)} 조회 실패: $e');
      }
    }
    candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final seen = <DateTime>{};
    candles = candles.where((c) => seen.add(c.timestamp)).toList();
    cacheFile.writeAsStringSync(jsonEncode(
        candles.map((c) => _candleToJson(c)).toList()));
    print('  ${candles.length}캔들 저장 완료');
  } else if (missingDays.isEmpty && candles.isNotEmpty) {
    print('  캐시 사용 (${candles.length}캔들, 최신: ${_fmtDate(lastDate)})');
  } else {
    print('  캐시 사용 (--download 없이 누락 ${missingDays.length}일 스킵)');
  }

  return candles;
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _candleToJson(Candle c) => {
      't': c.timestamp.toIso8601String(),
      'o': c.open,
      'h': c.high,
      'l': c.low,
      'c': c.close,
      'v': c.volume,
    };

Candle _parseCandle(Map<String, dynamic> m) => Candle(
      timestamp: DateTime.parse(m['t'] as String),
      open: (m['o'] as num).toDouble(),
      high: (m['h'] as num).toDouble(),
      low: (m['l'] as num).toDouble(),
      close: (m['c'] as num).toDouble(),
      volume: (m['v'] as num).toDouble(),
    );

double _detectTickSize(List<Candle> candles) {
  final avg =
      candles.map((c) => c.close).reduce((a, b) => a + b) / candles.length;
  if (avg >= 100000) return 100;
  if (avg >= 10000) return 50;
  if (avg >= 5000) return 10;
  return 5;
}

String _fmt(double v) {
  if (v == 0) return '0';
  return v < 0
      ? '-₩${v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
      : '₩${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
