import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// VWAP Cross 적합성 스크리너
/// 사용법: dart run bin/suitability.dart --code=005930
///         dart run bin/suitability.dart --all  (15개 전종목)
void main(List<String> args) async {
  final configFile = File('${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading\\kis_config.json');
  if (!configFile.existsSync()) { print('kis_config.json 없음'); exit(1); }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;
  final isPaper = appKey.startsWith('PS') ? true : ((config['is_paper'] as bool?) ?? true);
  final baseUrl = isPaper ? 'https://openapivts.koreainvestment.com:29443' : 'https://openapi.koreainvestment.com:9443';

  final codes = <String>[];
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--code' && i + 1 < args.length) codes.add(args[i + 1]);
    if (args[i].startsWith('--code=')) codes.add(args[i].substring(7));
  }
  final testAll = args.contains('--all');

  final knownList = [
    '005930', '000660', '005380', '012330', '097950',
    '207940', '373220', '068270', '018260', '105560',
    '000270', '003490', '002790', '055550', '090430',
  ];
  final stocks = testAll ? knownList : (codes.isNotEmpty ? codes : ['005930']);

  print('KIS: ${isPaper ? "모의" : "실전"} ($baseUrl)');

  // 캐싱된 토큰 재사용 (1분 1회 제한 대응)
  final tokenFile = File('${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading\\kis_token.txt');
  String? token;
  if (tokenFile.existsSync()) {
    final saved = tokenFile.readAsStringSync().trim();
    if (saved.isNotEmpty) token = saved;
  }
  if (token == null) {
    token = await _getToken(appKey, appSecret, baseUrl);
    if (token.isEmpty) { print('토큰 발급 실패. 1분 후 재시도'); exit(1); }
    tokenFile.writeAsStringSync(token);
    print('새 토큰 발급 완료');
  } else {
    print('캐싱된 토큰 사용');
  }
  print('테스트: ${stocks.length}개 종목\n');

  final allResults = <Map<String, dynamic>>[];
  final names = {
    '005930': '삼성전자', '000660': 'SK하이닉스', '005380': '현대차',
    '012330': '현대모비스', '097950': 'CJ제일제당', '207940': '삼성바이오로직스',
    '373220': 'LG에너지솔루션', '068270': '셀트리온', '018260': '삼성에스디에스',
    '105560': 'KB금융', '000270': '기아', '003490': '대한항공',
    '002790': '아모레G', '055550': '신한지주', '090430': '아모레퍼시픽',
  };

  for (final code in stocks) {
    final name = names[code] ?? code;
    print('$code $name');

    final candles = await _fetchDailyCandles(token, appKey, appSecret, baseUrl, code);
    if (candles.length < 30) { print('  데이터 부족\n'); continue; }

    final result = _evaluate(candles);
    final grade = result['grade'] as String;
    final gradeIcon = grade == '적합' ? '✅' : (grade == '부적합' ? '❌' : '⚠️');
    print('  $gradeIcon 적합도: $grade');
    print('    VWAP 순손익: ${result['netReturn'] > 0 ? "+" : ""}${(result['netReturn'] as double).toStringAsFixed(0)}원');
    print('    승률: ${(result['winRate'] * 100).toStringAsFixed(1)}%');
    print('    거래: ${result['trades']}건');
    print('    CI(추세성): ${(result['ci'] as double).toStringAsFixed(1)} (${(result['ci'] as double) < 45 ? "추세장" : (result['ci'] as double) > 50 ? "횡보장" : "혼합"})');

    allResults.add({'code': code, 'name': name, 'grade': grade,
      'netReturn': result['netReturn'], 'winRate': result['winRate'],
      'trades': result['trades'], 'ci': result['ci']});
    print('');
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // 결과 저장
  allResults.sort((a, b) => (b['grade'] as String).compareTo(a['grade'] as String));
  final saveDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  File('$saveDir\\suitability_results.json').writeAsStringSync(jsonEncode(allResults));

  // 요약 출력
  print('\n========== 적합성 평가 결과 ==========');
  for (final r in allResults) {
    final g = r['grade'] as String;
    final ret = r['netReturn'] as double;
    print('${g == "적합" ? "✅" : (g == "부적합" ? "❌" : "⚠️")} $g: ${r["code"]} ${r["name"]} (${ret >= 0 ? "+" : ""}${ret.toStringAsFixed(0)}원, 승률 ${(r["winRate"]*100).toStringAsFixed(1)}%)');
  }

  final suitable = allResults.where((r) => r['grade'] == '적합').length;
  final unsuitable = allResults.where((r) => r['grade'] == '부적합').length;
  final avg = allResults.where((r) => r['grade'] == '보통').length;
  print('\n✅ 적합: $suitable개  ⚠️ 보통: $avg개  ❌ 부적합: $unsuitable개');
  print('저장: $saveDir\\suitability_results.json');
}

/// VWAP Cross 적합성 평가
Map<String, dynamic> _evaluate(List<Map<String, dynamic>> candles) {
  final close = candles.map((c) => (c['c'] as num).toDouble()).toList();
  final high = candles.map((c) => (c['h'] as num).toDouble()).toList();
  final low = candles.map((c) => (c['l'] as num).toDouble()).toList();
  final vol = candles.map((c) => (c['v'] as num).toDouble()).toList();

  // 1. VWAP 계산
  double cumTpv = 0, cumVol = 0;
  final vwap = <double>[];
  for (int i = 0; i < close.length; i++) {
    final tp = (high[i] + low[i] + close[i]) / 3;
    cumTpv += tp * vol[i]; cumVol += vol[i];
    vwap.add(cumTpv / cumVol);
  }

  // 2. VWAP Cross 백테스트
  double entryP = 0; bool inPos = false; bool isLong = false;
  int trades = 0, wins = 0; double netPnl = 0;
  for (int i = 1; i < close.length; i++) {
    if (!inPos) {
      if (close[i-1] <= vwap[i-1] && close[i] > vwap[i]) { isLong = true; entryP = close[i]; inPos = true; }
      else if (close[i-1] >= vwap[i-1] && close[i] < vwap[i]) { isLong = false; entryP = close[i]; inPos = true; }
    } else {
      final exit = (isLong && close[i] < vwap[i]) || (!isLong && close[i] > vwap[i]);
      if (!exit && i < close.length - 1) continue;
      final pnl = isLong ? close[i] - entryP : entryP - close[i];
      final comm = (entryP + close[i]) * 0.00147;
      final net = pnl - comm; netPnl += net; trades++;
      if (net > 0) wins++; inPos = false;
    }
  }

  final winRate = trades > 0 ? wins / trades : 0.0;

  // 3. Choppiness Index (일봉 기준)
  final avgCi = _calcCi(high, low, close);

  // 4. 적합도 판정
  String grade;
  if (winRate > 0.40 && netPnl >= 0 && avgCi < 50) grade = '적합';
  else if (winRate > 0.35 && netPnl > -50000 && avgCi < 55) grade = '보통';
  else grade = '부적합';

  return {'netReturn': netPnl, 'winRate': winRate, 'trades': trades, 'ci': avgCi, 'grade': grade};
}

double _calcCi(List<double> high, List<double> low, List<double> close) {
  if (high.length < 15) return 50;
  final tr = <double>[];
  tr.add(high[0] - low[0]);
  for (int i = 1; i < high.length; i++) {
    final hl = high[i] - low[i];
    final hc = (high[i] - close[i-1]).abs();
    final lc = (low[i] - close[i-1]).abs();
    tr.add([hl, hc, lc].reduce((a,b) => a > b ? a : b));
  }
  // 전체 기간 평균 CI
  double sumTr = 0;
  for (int i = high.length - 14; i < high.length; i++) sumTr += tr[i];
  final maxH = high.sublist(high.length - 14).reduce((a,b) => a > b ? a : b);
  final minL = low.sublist(low.length - 14).reduce((a,b) => a < b ? a : b);
  final range = maxH - minL;
  if (range <= 0 || sumTr <= 0) return 50;
  return 100 * log(sumTr / range) / log(14);
}

// ---- KIS API ----

Future<String> _getToken(String key, String secret, String baseUrl) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    r.headers.set('Content-Type', 'application/json');
    r.write(jsonEncode({'grant_type': 'client_credentials', 'appkey': key, 'appsecret': secret}));
    final res = await r.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['access_token'] as String? ?? '';
  } finally { c.close(); }
}

Future<List<Map<String, dynamic>>> _fetchDailyCandles(
    String token, String key, String secret, String baseUrl, String symbol) async {
  final now = DateTime.now();
  final start = DateTime(now.year - 1, now.month, now.day);
  final c = HttpClient();
  try {
    final r = await c.getUrl(Uri.parse(
      '$baseUrl/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice'
      '?FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=$symbol'
      '&FID_INPUT_DATE_1=${start.year}${start.month.toString().padLeft(2,'0')}${start.day.toString().padLeft(2,'0')}'
      '&FID_INPUT_DATE_2=${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}'
      '&FID_PERIOD_DIV_CODE=D&FID_ORG_ADJ_PRC=0'));
    r.headers.set('Content-Type', 'application/json');
    r.headers.set('authorization', 'Bearer $token');
    r.headers.set('appkey', key); r.headers.set('appsecret', secret);
    r.headers.set('custtype', 'P'); r.headers.set('tr_id', 'FHKST03010100');
    final res = await r.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['rt_cd'] != '0') return [];
    return (json['output2'] as List<dynamic>?)
        ?.reversed.map((e) => {
      'c': double.parse((e as Map)['stck_clpr'] as String),
      'h': double.parse(e['stck_hgpr'] as String),
      'l': double.parse(e['stck_lwpr'] as String),
      'v': double.parse(e['acml_vol'] as String),
    }).toList() ?? [];
  } finally { c.close(); }
}
