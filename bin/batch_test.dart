import 'dart:convert';
import 'dart:io';

import 'package:beyondi_trading/features/backtest/domain/entities/candle.dart';
import 'package:beyondi_trading/features/backtest/domain/usecases/run_backtest.dart';

void main(List<String> args) async {
  final configFile = File('${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading\\kis_config.json');
  if (!configFile.existsSync()) { print('kis_config.json 없음'); exit(1); }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;
  final isPaper = (config['is_paper'] as bool?) ?? true;
  final isReal = args.contains('--real') ? true : !isPaper;

  final stocks = [
    {'code': '002790', 'name': '아모레G'},
    {'code': '207940', 'name': '삼성바이오로직스'},
    {'code': '090430', 'name': '아모레퍼시픽'},
    {'code': '068270', 'name': '셀트리온'},
    {'code': '097950', 'name': 'CJ제일제당'},
    {'code': '003490', 'name': '대한항공'},
    {'code': '373220', 'name': 'LG에너지솔루션'},
    {'code': '055550', 'name': '신한지주'},
    {'code': '105560', 'name': 'KB금융'},
    {'code': '000270', 'name': '기아'},
    {'code': '018260', 'name': '삼성에스디에스'},
    {'code': '012330', 'name': '현대모비스'},
    {'code': '005380', 'name': '현대차'},
    {'code': '005930', 'name': '삼성전자'},
    {'code': '000660', 'name': 'SK하이닉스'},
  ];

  print('>>> 배치 테스트 시작 (isReal=$isReal)');
  print('>>> ${stocks.length}개 종목\n');

  final allResults = <Map<String, dynamic>>[];

  for (int idx = 0; idx < stocks.length; idx++) {
    final s = stocks[idx];
    final code = s['code'] as String;
    final name = s['name'] as String;
    print('[${idx+1}/${stocks.length}] $code $name');

    // 캐시된 분봉 데이터 확인
    var candles = _loadCachedMinute(code);
    if (candles == null || candles.length < 500) {
      print('  분봉 데이터 없음. 다운로드 필요 (Flutter 앱에서 직접 로드)');
      print('  SKIP: 앱에서 데이터 로드 후 재실행 필요');
      allResults.add({'code': code, 'name': name, 'netReturn': null, 'error': 'need_download'});
      continue;
    }

    final ts = _detectTickSize(candles);
    print('  ${candles.length}캔들, 틱=$ts');

    // 손실 방지 최적화: 기본(VWAP Cross) + 진입틱/RSI 조합 테스트
    final configs = <Map<String, dynamic>>[
      {'label': '기본    ', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': false, 'ob': 70.0, 'os': 30.0},
      {'label': 'RSI30-70', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': 'RSI35-65', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 65.0, 'os': 35.0},
      {'label': '진입10   ', 'entry': 10.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': '진입15   ', 'entry': 15.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': '진입20   ', 'entry': 20.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': 'TP15/SL10', 'entry': 5.0, 'tp': 15.0, 'sl': 10.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
    ];

    double best = -999999;
    double bestNet = -999999; // commission 포함
    String bestLabel = '';
    final stockResults = <Map<String, dynamic>>[];

    for (final cfg in configs) {
      final r = runBacktest(
        candles: candles, tickSize: ts,
        entryThresholdTicks: cfg['entry'] as double,
        takeProfitTicks: cfg['tp'] as double,
        stopLossTicks: cfg['sl'] as double,
        useRsiFilter: cfg['rsi'] as bool,
        rsiOverbought: cfg['ob'] as double,
        rsiOversold: cfg['os'] as double,
        closeAtEndOfDay: true,
        mode: 'vwap_cross',
        commissionPercent: 0.147,
      );

      stockResults.add({
        'label': cfg['label'],
        'netReturn': r.netReturn, 'totalReturn': r.totalReturn,
        'commission': r.totalCommission, 'trades': r.totalSignals,
        'winRate': r.winRate, 'sharpe': r.sharpeRatio,
      });

      if (r.netReturn > best) {
        best = r.netReturn; bestNet = r.netReturn; bestLabel = cfg['label'] as String;
      }
    }

    print('  최고: ${best.toStringAsFixed(0)}원 ($bestLabel)');
    for (final sr in stockResults) {
      final sign = (sr['netReturn'] as double) >= 0 ? '+' : '';
      print('    ${sr['label']}: ${sign}${(sr['netReturn'] as double).toStringAsFixed(0)}원 (${sr['trades']}건, ${(sr['winRate']*100).toStringAsFixed(1)}%)');
    }

    allResults.add({
      'code': code, 'name': name, 'bestLabel': bestLabel,
      'netReturn': best, 'configs': stockResults,
    });
  }

  // 종합 결과
  print('\n\n========== 배치 테스트 결과 ==========');
  final profitable = allResults.where((r) => r['netReturn'] != null && (r['netReturn'] as double) >= 0).toList();
  final losing = allResults.where((r) => r['netReturn'] != null && (r['netReturn'] as double) < 0).toList();
  final skipped = allResults.where((r) => r['netReturn'] == null).toList();

  allResults.sort((a, b) => ((b['netReturn'] as double?) ?? -999999).compareTo((a['netReturn'] as double?) ?? -999999));

  print('✅ 수익: ${profitable.length}개');
  for (final r in profitable) {
    final sign = (r['netReturn'] as double) >= 0 ? '+' : '';
    print('  ${sign}${(r['netReturn'] as double).toStringAsFixed(0)}원 ${r['code']} ${r['name']} (${r['bestLabel']})');
  }

  print('\n❌ 손실: ${losing.length}개');
  for (final r in losing) {
    final sign = (r['netReturn'] as double) >= 0 ? '+' : '';
    print('  ${sign}${(r['netReturn'] as double).toStringAsFixed(0)}원 ${r['code']} ${r['name']} (${r['bestLabel']})');
  }

  if (skipped.isNotEmpty) {
    print('\n⏭ SKIP: ${skipped.length}개');
    for (final r in skipped) { print('  ${r['code']} ${r['name']}'); }
  }

  // 결과 저장
  final saveDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  File('$saveDir\\batch_results.json').writeAsStringSync(jsonEncode(allResults));
  print('\n결과 저장됨: $saveDir\\batch_results.json');
}

List<Candle>? _loadCachedMinute(String symbol) {
  final dir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  if (dir.isEmpty) return null;
  final d = Directory(dir);
  if (!d.existsSync()) return null;
  final files = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_${symbol}_') && f.path.endsWith('_1d.json')).toList();
  if (files.isEmpty) return null;
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  final raw = jsonDecode(files.first.readAsStringSync()) as List<dynamic>;
  return raw.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
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
