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

  final stocks = _allStocks();

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

    // 손실 방지 최적화: hybrid 7개 + vwap_scalp 3개
    final configs = <Map<String, dynamic>>[
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

    double best = -999999;
    double bestNet = -999999; // commission 포함
    String bestLabel = '';
    final stockResults = <Map<String, dynamic>>[];

    for (final cfg in configs) {
      final m = cfg['mode'] as String;
      final bool isScalp = m == 'vwap_scalp';
      final r = runBacktest(
        candles: candles, tickSize: ts,
        entryThresholdTicks: isScalp ? 0 : (cfg['entry'] as double? ?? 0),
        takeProfitTicks: isScalp ? 0 : (cfg['tp'] as double? ?? 0),
        stopLossTicks: isScalp ? 0 : (cfg['sl'] as double? ?? 0),
        useRsiFilter: isScalp ? false : (cfg['rsi'] as bool? ?? false),
        rsiOverbought: cfg['ob'] as double? ?? 70,
        rsiOversold: cfg['os'] as double? ?? 30,
        closeAtEndOfDay: true,
        mode: m,
        commissionPercent: 0.147,
        principal: 300000,
        consecutiveLossLimit: (isScalp || m == 'orb' || m == 'ema_trend') ? 100 : 3,
        dailyLossLimit: 50000,
        maxTotalLoss: 100000,
        longOnly: true,
        // vwap_scalp params
        scalpRsiThreshold: isScalp ? (cfg['rsi'] as num?)?.toDouble() ?? 30 : 30,
        scalpVolumeMultiplier: isScalp ? (cfg['vol'] as num?)?.toDouble() ?? 1.5 : 1.5,
        scalpEntryTicksMin: isScalp ? (cfg['minT'] as num?)?.toDouble() ?? 5 : 5,
        scalpEntryTicksMax: isScalp ? (cfg['maxT'] as num?)?.toDouble() ?? 15 : 15,
        scalpMaxHoldMinutes: isScalp ? (cfg['hold'] as int?) ?? 30 : 30,
        scalpStopLossTicks: isScalp ? (cfg['slt'] as num?)?.toDouble() ?? 3 : 3,
        // ORB params
        orbRangeMinutes: m == 'orb' ? (cfg['range'] as int?) ?? 30 : 30,
        // EMA params
        emaFastPeriod: m == 'ema_trend' ? (cfg['fast'] as int?) ?? 9 : 9,
        emaSlowPeriod: m == 'ema_trend' ? (cfg['slow'] as int?) ?? 21 : 21,
        adxThreshold: m == 'ema_trend' ? (cfg['adx'] as num?)?.toDouble() ?? 25 : 25,
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
  File('$saveDir\\batch_results_longonly.json').writeAsStringSync(jsonEncode(allResults));
  print('\n결과 저장됨: $saveDir\\batch_results_longonly.json');
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

List<Map<String, String>> _allStocks() => [
  // KOSPI 64
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
  // KOSDAQ 26
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
