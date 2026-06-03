import 'dart:convert';
import 'dart:io';

/// KIS Open API를 통해 1년 수익률 + VWAP Cross 기본 성능 스크리닝
void main(List<String> args) async {
  // 앱키 설정 읽기
  final configFile = File('${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading\\kis_config.json');
  if (!configFile.existsSync()) {
    print('kis_config.json 없음. Flutter 앱에서 KIS 연결 먼저 실행하세요.');
    exit(1);
  }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;
  final isPaper = appKey.startsWith('PS') ? true : ((config['is_paper'] as bool?) ?? true);
  final baseUrl = isPaper ? 'https://openapivts.koreainvestment.com:29443' : 'https://openapi.koreainvestment.com:9443';

  print('>>> KIS API 연결됨 ($appKey)');

  // 토큰 발급
  final token = await _getToken(appKey, appSecret, baseUrl);
  print('>>> 토큰 발급 완료');

  // 테스트 종목 리스트
  final stocks = [
    {'code': '005930', 'name': '삼성전자'},
    {'code': '000660', 'name': 'SK하이닉스'},
    {'code': '373220', 'name': 'LG에너지솔루션'},
    {'code': '207940', 'name': '삼성바이오로직스'},
    {'code': '105560', 'name': 'KB금융'},
    {'code': '097950', 'name': 'CJ제일제당'},
    {'code': '012330', 'name': '현대모비스'},
    {'code': '002790', 'name': '아모레G'},
    {'code': '090430', 'name': '아모레퍼시픽'},
    {'code': '018260', 'name': '삼성에스디에스'},
    {'code': '005380', 'name': '현대차'},
    {'code': '000270', 'name': '기아'},
    {'code': '068270', 'name': '셀트리온'},
    {'code': '055550', 'name': '신한지주'},
    {'code': '003490', 'name': '대한항공'},
  ];

  final results = <Map<String, dynamic>>[];

  for (final s in stocks) {
    final code = s['code'] as String;
    final name = s['name'] as String;
    print('\n>>> $code $name 조회 중...');

    try {
      final candles = await _fetchDailyCandles(token, appKey, appSecret, baseUrl, code);
      if (candles.isEmpty) {
        print('  데이터 없음');
        results.add({'code': code, 'name': name, 'err': 'no_data'});
        continue;
      }

      final firstPrice = candles.last['close'];  // oldest first
      final lastPrice = candles.first['close'];   // most recent
      final yearlyReturn = (lastPrice - firstPrice) / firstPrice * 100;
      final candleCount = candles.length;

      // VWAP Cross 기본 테스트
      final tickSize = (firstPrice >= 100000 ? 100 : (firstPrice >= 10000 ? 50 : (firstPrice >= 5000 ? 10 : 5))).toDouble();
      final testResult = await _quickVwapTest(candles, tickSize);

      print('  수익률: ${yearlyReturn.toStringAsFixed(1)}% (${candleCount}일) VWAP: ${testResult['netReturn'].toStringAsFixed(0)}원');
      results.add({
        'code': code, 'name': name,
        'yearlyReturn': yearlyReturn,
        'candleCount': candleCount,
        'vwapNet': testResult['netReturn'],
        'vwapTrades': testResult['trades'],
        'vwapWinRate': testResult['winRate'],
      });
    } catch (e) {
      print('  오류: $e');
      results.add({'code': code, 'name': name, 'err': e.toString()});
    }

    // API rate limit 방지
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // 결과 정리
  print('\n\n========== 스크리닝 결과 ==========');
  results.sort((a, b) => ((b['yearlyReturn'] as double?) ?? 0).compareTo((a['yearlyReturn'] as double?) ?? 0));
  print('\n--- 연간 수익률 기준 ---');
  for (final r in results) {
    final ret = r['yearlyReturn'];
    final vwap = r['vwapNet'];
    final trades = r['vwapTrades'];
    if (ret == null) { print('${r['code']} ${r['name']}: 오류'); continue; }
    final sign = ret >= 0 ? '+' : '';
    final vsign = (vwap is double && vwap >= 0) ? '+' : '';
    final vwapStr = (vwap is double) ? '${vsign}${vwap.toStringAsFixed(0)}원' : '-';
    print('${sign}${ret.toStringAsFixed(1)}%  ${r['code']} ${r['name']}  (VWAP: ${vwapStr}, ${trades ?? "?"}건)');
  }

  // VWAP Cross 성능 기준
  results.sort((a, b) => ((b['vwapNet'] as double?) ?? -999999).compareTo((a['vwapNet'] as double?) ?? -999999));
  print('\n--- VWAP Cross 성능 기준 ---');
  for (final r in results) {
    final vwap = r['vwapNet'];
    if (vwap == null) continue;
    final vsign = (vwap is double && vwap >= 0) ? '+' : '';
    final ret = r['yearlyReturn'];
    final retStr = (ret is double) ? '${ret.toStringAsFixed(1)}%' : '-';
    print('${vsign}${(vwap as double).toStringAsFixed(0)}원  ${r['code']} ${r['name']}  (수익률: $retStr)');
  }

  // 분류
  print('\n\n--- 추천 분류 (연간 수익률 기준) ---');
  results.sort((a, b) => ((b['yearlyReturn'] as double?) ?? 0).compareTo((a['yearlyReturn'] as double?) ?? 0));
  final valid = results.where((r) => r['yearlyReturn'] != null).toList();
  for (int i = 0; i < valid.length; i++) {
    final label = i < 5 ? '상승' : (i >= valid.length - 5 ? '하락' : '평균');
    final r = valid[i];
    print('${label == '상승' ? '🟢' : (label == '하락' ? '🔴' : '🟡')} $label: ${r['code']} ${r['name']} (${(r['yearlyReturn'] as double).toStringAsFixed(1)}%)');
  }
}

Future<String> _getToken(String key, String secret, String baseUrl) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode({
      'grant_type': 'client_credentials', 'appkey': key, 'appsecret': secret,
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['access_token'] as String;
  } finally {
    client.close();
  }
}

Future<List<Map<String, dynamic>>> _fetchDailyCandles(
    String token, String key, String secret, String baseUrl, String symbol) async {
  final now = DateTime.now();
  final start = DateTime(now.year - 1, now.month, now.day);
  final end = now;

  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(
      '$baseUrl/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice'
      '?FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=$symbol'
      '&FID_INPUT_DATE_1=${start.year}${start.month.toString().padLeft(2,'0')}${start.day.toString().padLeft(2,'0')}'
      '&FID_INPUT_DATE_2=${end.year}${end.month.toString().padLeft(2,'0')}${end.day.toString().padLeft(2,'0')}'
      '&FID_PERIOD_DIV_CODE=D&FID_ORG_ADJ_PRC=0'
    ));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('authorization', 'Bearer $token');
    req.headers.set('appkey', key);
    req.headers.set('appsecret', secret);
    req.headers.set('custtype', 'P');
    req.headers.set('tr_id', 'FHKST03010100');

    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (json['rt_cd'] != '0') {
      print('  API 오류: ${json['msg1']}');
      return [];
    }

    final list = json['output2'] as List<dynamic>;
    return list.reversed.map((e) => {
      'close': double.parse((e as Map)['stck_clpr'] as String),
      'high': double.parse(e['stck_hgpr'] as String),
      'low': double.parse(e['stck_lwpr'] as String),
      'volume': double.parse(e['acml_vol'] as String),
    }).toList();
  } finally {
    client.close();
  }
}

/// 간단 VWAP Cross 테스트 (일봉용)
Future<Map<String, dynamic>> _quickVwapTest(List<Map<String, dynamic>> candles, double tickSize) async {
  if (candles.length < 20) return {'netReturn': 0.0, 'trades': 0, 'winRate': 0.0};

  double cumTpv = 0, cumVol = 0;
  final vwapSeries = <double>[];
  for (final c in candles) {
    final tp = (c['high'] + c['low'] + c['close']) / 3;
    cumTpv += tp * c['volume'];
    cumVol += c['volume'];
    vwapSeries.add(cumTpv / cumVol);
  }

  double entryPrice = 0;
  DateTime? entryTime;
  bool inPosition = false;
  bool isLong = false;
  int trades = 0, wins = 0;
  double netPnl = 0, commission = 0;

  for (int i = 1; i < candles.length; i++) {
    final price = candles[i]['close'] as double;
    final vwap = vwapSeries[i];
    final prevPrice = candles[i-1]['close'] as double;
    final prevVwap = vwapSeries[i-1];

    if (!inPosition) {
      if (prevPrice <= prevVwap && price > vwap) {
        isLong = true; entryPrice = price; inPosition = true; entryTime = DateTime.now();
      } else if (prevPrice >= prevVwap && price < vwap) {
        isLong = false; entryPrice = price; inPosition = true; entryTime = DateTime.now();
      }
    } else {
      final tradePnl = isLong ? price - entryPrice : entryPrice - price;
      final comm = (entryPrice + price) * (0.147 / 100);

      if ((isLong && price < vwap) || (!isLong && price > vwap)) {
        final net = tradePnl - comm;
        netPnl += net; commission += comm; trades++;
        if (net > 0) wins++;
        inPosition = false;
      }
    }
  }

  // 마지막 포지션 청산
  if (inPosition) {
    final price = candles.last['close'] as double;
    final tradePnl = isLong ? price - entryPrice : entryPrice - price;
    final comm = (entryPrice + price) * (0.147 / 100);
    final net = tradePnl - comm;
    netPnl += net; commission += comm; trades++;
    if (net > 0) wins++;
  }

  return {'netReturn': netPnl, 'trades': trades, 'winRate': trades > 0 ? wins / trades : 0.0};
}
