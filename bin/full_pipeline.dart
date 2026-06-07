import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// 15개 종목 분봉 데이터 다운로드 → 최적화 → 결과 저장
void main(List<String> args) async {
  final configFile = File('${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading\\kis_config.json');
  if (!configFile.existsSync()) { print('kis_config.json 없음'); exit(1); }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;
  final isPaper = appKey.startsWith('PS') ? true : ((config['is_paper'] as bool?) ?? true);
  final baseUrl = isPaper ? 'https://openapivts.koreainvestment.com:29443' : 'https://openapi.koreainvestment.com:9443';
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final limited = args.contains('--quick');

  // --stock 옵션으로 단일 종목 테스트
  String? singleCode;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--stock' && i + 1 < args.length) singleCode = args[i + 1];
    if (args[i].startsWith('--stock=')) singleCode = args[i].substring(8);
  }

  print('KIS API: $baseUrl (isPaper=$isPaper)');
  final tokenFile = File('$cacheDir\\kis_token.txt');
  var token = tokenFile.existsSync() ? tokenFile.readAsStringSync().trim() : '';
  if (token.isEmpty) {
    token = await _getToken(appKey, appSecret, baseUrl);
    if (token.isEmpty) { print('토큰 발급 실패'); exit(1); }
    tokenFile.writeAsStringSync(token);
    print('새 토큰 발급 완료');
  } else {
    print('캐싱된 토큰 사용');
  }

  final allStocks = [
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
    {'code': '005490', 'name': 'POSCO홀딩스'},
  ];
  final stocks = singleCode != null
      ? allStocks.where((s) => s['code'] == singleCode).toList()
      : allStocks;

  final allResults = <Map<String, dynamic>>[];
  final endDate = DateTime.now();
  final startDate = DateTime(endDate.year - 1, endDate.month, endDate.day);

  for (int idx = 0; idx < stocks.length; idx++) {
    final s = stocks[idx];
    final code = s['code'] as String;
    final name = s['name'] as String;
    print('===== [${idx+1}/${stocks.length}] $code $name =====');

    // 1. 캐시 확인
    var candles = _loadCached(cacheDir, code);
    if (candles == null || candles.length < 500) {
      print('  → 분봉 다운로드 중...');
      candles = await _downloadMinuteCandles(token, appKey, appSecret, baseUrl, code, startDate, endDate, limited);
      if (candles.isEmpty) { print('  실패'); continue; }
      _saveCandles(cacheDir, code, startDate, endDate, candles);
      print('  ${candles.length}캔들 저장 완료');
    } else {
      print('  캐시 사용: ${candles.length}캔들');
    }

    // 2. 최적화
    final ts = _detectTickSize(candles);
    final configs = [
      {'label': '기본    ', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': false, 'ob': 70.0, 'os': 30.0},
      {'label': 'RSI30-70', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': 'RSI35-65', 'entry': 0.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 65.0, 'os': 35.0},
      {'label': '진입20   ', 'entry': 20.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': '진입15   ', 'entry': 15.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': '진입10   ', 'entry': 10.0, 'tp': 0.0, 'sl': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
    ];

    double best = -999999;
    String bestLabel = '';
    final details = <Map<String, dynamic>>[];

    for (final cfg in configs) {
      final r = _runBacktest(candles, ts,
        cfg['entry'] as double, cfg['tp'] as double, cfg['sl'] as double,
        cfg['rsi'] as bool, cfg['ob'] as double, cfg['os'] as double);
      details.add({
        'label': cfg['label'], 'netReturn': r['net'], 'trades': r['trades'],
        'winRate': r['winRate'], 'commission': r['commission'],
      });
      if ((r['net'] as double) > best) {
        best = r['net'] as double; bestLabel = cfg['label'] as String;
      }
    }

    print('  최고: ${best.toStringAsFixed(0)}원 ($bestLabel)');
    for (final d in details) {
      final sign = (d['netReturn'] as double) >= 0 ? '+' : '';
      print('    ${d['label']}: ${sign}${(d['netReturn'] as double).toStringAsFixed(0)}원 (${d['trades']}건)');
    }

    allResults.add({'code': code, 'name': name, 'best': best, 'bestLabel': bestLabel, 'details': details});
  }

  // 종합
  print('\n\n========== 최종 결과 ==========');
  allResults.sort((a, b) => ((b['best'] as double?) ?? -999999).compareTo((a['best'] as double?) ?? -999999));
  int win = 0, lose = 0;
  for (final r in allResults) {
    if (r['best'] == null) continue;
    if ((r['best'] as double) >= 0) win++; else lose++;
    final sign = (r['best'] as double) >= 0 ? '+' : '';
    print('${sign}${(r['best'] as double).toStringAsFixed(0)}원 ${r['code']} ${r['name']} (${r['bestLabel']})');
  }
  print('\n수익: $win개 / 손실: $lose개 / 전체: ${allResults.length}개');

  File('$cacheDir\\full_results.json').writeAsStringSync(jsonEncode(allResults));
  print('저장: $cacheDir\\full_results.json');
}

// ---- KIS API 통신 ----

Future<String> _getToken(String key, String secret, String baseUrl) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    r.headers.set('Content-Type', 'application/json');
    r.write(jsonEncode({'grant_type': 'client_credentials', 'appkey': key, 'appsecret': secret}));
    final res = await r.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['access_token'] == null) {
      print('토큰 발급 실패: ${json['msg1'] ?? json['error_description'] ?? body}');
      return '';
    }
    return json['access_token'] as String;
  } finally { c.close(); }
}

Future<List<Map<String, dynamic>>> _fetchMinuteChunk(
    String token, String key, String secret, String baseUrl,
    String symbol, DateTime date, String startTime) async {
  final ds = '${date.year}${date.month.toString().padLeft(2,'0')}${date.day.toString().padLeft(2,'0')}';
  final c = HttpClient();
  try {
    final r = await c.getUrl(Uri.parse(
      '$baseUrl/uapi/domestic-stock/v1/quotations/inquire-time-dailychartprice'
      '?FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=$symbol'
      '&FID_INPUT_HOUR_1=$startTime&FID_INPUT_DATE_1=$ds'
      '&FID_PW_DATA_INCU_YN=Y&FID_FAKE_TICK_INCU_YN=N'));
    r.headers.set('Content-Type', 'application/json');
    r.headers.set('authorization', 'Bearer $token');
    r.headers.set('appkey', key); r.headers.set('appsecret', secret);
    r.headers.set('custtype', 'P'); r.headers.set('tr_id', 'FHKST03010230');
    final res = await r.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['rt_cd'] != '0') return [];
    return ((json['output2'] as List<dynamic>?) ?? []).map((e) => {
      't': '${ds}T${(e as Map)['stck_cntg_hour'] as String}',
      'o': double.parse((e['stck_oprc'] as String)),
      'h': double.parse((e['stck_hgpr'] as String)),
      'l': double.parse((e['stck_lwpr'] as String)),
      'c': double.parse((e['stck_prpr'] as String)),
      'v': double.parse((e['cntg_vol'] as String)),
    }).toList();
  } catch (_) { return []; } finally { c.close(); }
}

Future<List<Map<String, dynamic>>> _downloadMinuteCandles(
    String token, String key, String secret, String baseUrl,
    String symbol, DateTime start, DateTime end, bool limited) async {
  final all = <Map<String, dynamic>>[];
  int maxDays = limited ? 30 : end.difference(start).inDays;

  for (int d = 0; d <= maxDays; d++) {
    final date = start.add(Duration(days: d));
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;

    final chunks = await Future.wait(
      ['093000', '113000', '133000', '153000'].map((t) =>
        _fetchMinuteChunk(token, key, secret, baseUrl, symbol, date, t)));
    final seen = <String>{};
    for (final chunk in chunks) {
      for (final c in chunk) {
        if (seen.add(c['t'] as String)) all.add(c);
      }
    }
    if (d % 20 == 0) print('  ${d}/${maxDays}일 (${all.length}캔들)');
    await Future.delayed(const Duration(milliseconds: 80));
  }
  return all;
}

// ---- 캐시 ----

List<Map<String, dynamic>>? _loadCached(String dir, String symbol) {
  final d = Directory(dir); if (!d.existsSync()) return null;
  final fullFile = File('$dir\\candle_${symbol}_full_1d.json');
  if (fullFile.existsSync()) {
    return (jsonDecode(fullFile.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();
  }
  final oldFiles = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_${symbol}_') && !f.path.contains('_full_') && f.path.endsWith('_1d.json')).toList();
  if (oldFiles.isEmpty) return null;
  oldFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  final data = (jsonDecode(oldFiles.first.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();
  fullFile.writeAsStringSync(jsonEncode(data));
  for (final f in oldFiles) { try { f.deleteSync(); } catch (_) {} }
  return data;
}

void _saveCandles(String dir, String symbol, DateTime start, DateTime end, List<Map<String, dynamic>> candles) {
  if (candles.isEmpty) return;
  final file = File('$dir\\candle_${symbol}_full_1d.json');
  List<Map<String, dynamic>> existing = [];
  if (file.existsSync()) {
    try { existing = (jsonDecode(file.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>(); }
    catch (_) {}
  }
  existing.addAll(candles);
  existing.sort((a, b) => (a['t'] as String).compareTo(b['t'] as String));
  final seen = <String>{};
  existing.retainWhere((e) => seen.add(e['t'] as String));
  file.writeAsStringSync(jsonEncode(existing));
}

double _detectTickSize(List<Map<String, dynamic>> candles) {
  double sum = 0; for (final c in candles) sum += (c['c'] as num).toDouble();
  final avg = sum / candles.length;
  if (avg >= 100000) return 100;
  if (avg >= 10000) return 50;
  if (avg >= 5000) return 10;
  return 5;
}

// ---- 경량 백테스트 (의존성 없이) ----

Map<String, dynamic> _runBacktest(List<Map<String, dynamic>> candles, double ts,
    double entry, double tp, double sl, bool useRsi, double ob, double os) {
  if (candles.length < 30) return {'net': 0.0, 'trades': 0, 'winRate': 0.0, 'commission': 0.0};

  final close = candles.map((c) => (c['c'] as num).toDouble()).toList();
  final high = candles.map((c) => (c['h'] as num).toDouble()).toList();
  final low = candles.map((c) => (c['l'] as num).toDouble()).toList();

  // VWAP
  double cumTpv = 0, cumVol = 0;
  final vwap = <double>[];
  for (final c in candles) {
    final tp = (c['h'] + c['l'] + c['c']) / 3;
    cumTpv += (tp as num).toDouble() * (c['v'] as num).toDouble();
    cumVol += (c['v'] as num).toDouble();
    vwap.add(cumTpv / cumVol);
  }

  // RSI
  List<double>? rsi;
  if (useRsi) rsi = _calcRsi(close);

  double entryP = 0; bool inPos = false; bool isLong = false;
  int trades = 0, wins = 0;
  double netPnl = 0, totComm = 0;

  for (int i = 1; i < close.length; i++) {
    if (!inPos) {
      bool signal = false;
      if (close[i] > vwap[i] && close[i-1] <= vwap[i-1]) { isLong = true; signal = true; }
      else if (close[i] < vwap[i] && close[i-1] >= vwap[i-1]) { isLong = false; signal = true; }
      if (!signal) continue;

      if (entry > 0 && (close[i] - vwap[i]).abs() < entry * ts) continue;
      if (useRsi && rsi != null && i < rsi.length) {
        if (isLong && rsi[i] > ob) continue;
        if (!isLong && rsi[i] < os) continue;
      }
      entryP = close[i]; inPos = true;
    } else {
      final rawPnl = isLong ? close[i] - entryP : entryP - close[i];
      if (tp > 0) {
        final hitPrice = isLong ? high[i] : low[i];
        final hitPnl = isLong ? hitPrice - entryP : entryP - hitPrice;
        if (hitPnl >= tp * ts) { rawPnl >= 0; /* rely on close */ }
      }
      if (sl > 0) {
        final hitPrice = isLong ? low[i] : high[i];
        final hitPnl = isLong ? hitPrice - entryP : entryP - hitPrice;
        if (hitPnl <= -(sl * ts)) { /* rely on close */ }
      }

      final crossed = (isLong && close[i] < vwap[i]) || (!isLong && close[i] > vwap[i]);
      if (!crossed && !(close[i] == candles.last['c'])) continue;

      final comm = (entryP + close[i]) * 0.00147;
      final net = rawPnl - comm;
      netPnl += net; totComm += comm; trades++;
      if (net > 0) wins++;
      inPos = false;
    }
  }

  return {'net': netPnl, 'trades': trades, 'winRate': trades > 0 ? wins / trades : 0.0, 'commission': totComm};
}

List<double> _calcRsi(List<double> close) {
  if (close.length < 15) return List.filled(close.length, 50);
  final changes = <double>[];
  for (int i = 1; i < close.length; i++) changes.add(close[i] - close[i-1]);
  final rsi = List.filled(close.length, 50.0);
  double avgG = 0, avgL = 0;
  for (int i = 0; i < 14; i++) { if (changes[i] > 0) avgG += changes[i]; else avgL -= changes[i]; }
  avgG /= 14; avgL /= 14;
  rsi[14] = avgL == 0 ? 100 : (avgG == 0 ? 0 : 100 - 100 / (1 + avgG / avgL));
  for (int i = 15; i < close.length; i++) {
    final g = changes[i-1] > 0 ? changes[i-1] : 0;
    final l = changes[i-1] < 0 ? -changes[i-1] : 0;
    avgG = (avgG * 13 + g) / 14; avgL = (avgL * 13 + l) / 14;
    rsi[i] = avgL == 0 ? 100 : (avgG == 0 ? 0 : 100 - 100 / (1 + avgG / avgL));
  }
  return rsi;
}
