import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// 10개 신규 종목 데이터 다운로드 + 최적화
void main(List<String> args) async {
  final configFile = File('${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading\\kis_config.json');
  if (!configFile.existsSync()) { print('kis_config.json 없음'); exit(1); }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;
  final isPaper = appKey.startsWith('PS') ? true : ((config['is_paper'] as bool?) ?? true);
  final baseUrl = isPaper ? 'https://openapivts.koreainvestment.com:29443' : 'https://openapi.koreainvestment.com:9443';
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';

  print('KIS API: $baseUrl');
  final tokenFile = File('$cacheDir\\kis_token.txt');
  var token = tokenFile.existsSync() ? tokenFile.readAsStringSync().trim() : '';
  if (token.isEmpty) {
    token = await _getToken(appKey, appSecret, baseUrl);
    if (token.isEmpty) { print('토큰 발급 실패'); exit(1); }
    tokenFile.writeAsStringSync(token); print('새 토큰 발급');
  } else print('캐싱된 토큰 사용');

  final stocks = [
    {'code': '066570', 'name': 'LG전자'},        // +266,645원 gross
    {'code': '259960', 'name': '크래프톤'},       // 승률 42.9%
    {'code': '352820', 'name': '하이브'},          // 소폭 수익
    {'code': '000100', 'name': '유한양행'},        // 승률 66.7%
    {'code': '086280', 'name': '현대글로비스'},     // 추세장 CI
    {'code': '051910', 'name': 'LG화학'},
    {'code': '028260', 'name': '삼성물산'},
    {'code': '011200', 'name': 'HMM'},
    {'code': '006400', 'name': '삼성SDI'},
    {'code': '034020', 'name': '두산에너빌리티'},
  ];

  final allResults = <Map<String, dynamic>>[];
  final endDate = DateTime.now();
  final startDate = DateTime(endDate.year - 1, endDate.month, endDate.day);

  for (int idx = 0; idx < stocks.length; idx++) {
    final s = stocks[idx];
    final code = s['code'] as String;
    final name = s['name'] as String;
    print('\n===== [${idx+1}/${stocks.length}] $code $name =====');

    var candles = _loadCached(cacheDir, code);
    if (candles == null || candles.length < 500) {
      print('  분봉 다운로드 중...');
      candles = await _downloadMinute(token, appKey, appSecret, baseUrl, code, startDate, endDate);
      if (candles.isEmpty) { print('  실패'); continue; }
      _saveCandles(cacheDir, code, startDate, endDate, candles);
      print('  ${candles.length}캔들 저장');
    } else print('  캐시 사용: ${candles.length}캔들');

    final ts = _detectTickSize(candles);
    final configs = [
      {'label': '기본    ', 'entry': 0.0, 'rsi': false},
      {'label': 'RSI30-70', 'entry': 0.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
      {'label': 'RSI35-65', 'entry': 0.0, 'rsi': true, 'ob': 65.0, 'os': 35.0},
      {'label': '진입20   ', 'entry': 20.0, 'rsi': true, 'ob': 70.0, 'os': 30.0},
    ];

    double best = -999999; String bestLabel = '';
    final details = <Map<String, dynamic>>[];

    for (final cfg in configs) {
      final r = _runBT(candles, ts,
        cfg['entry'] as double, cfg['rsi'] as bool,
        (cfg['ob'] as double?) ?? 70, (cfg['os'] as double?) ?? 30);
      if ((r['net'] as double) > best) { best = r['net'] as double; bestLabel = cfg['label'] as String; }
      details.add({'label': cfg['label'], 'net': r['net'], 'trades': r['trades'], 'winRate': r['winRate']});
    }

    print('  최고: ${best >= 0 ? "+" : ""}${best.toStringAsFixed(0)}원 ($bestLabel)');
    for (final d in details) {
      final n = d['net'] as double;
      print('    ${d['label']}: ${n >= 0 ? "+" : ""}${n.toStringAsFixed(0)}원 (${d['trades']}건, ${((d['winRate'] as double)*100).toStringAsFixed(1)}%)');
    }
    allResults.add({'code': code, 'name': name, 'best': best, 'bestLabel': bestLabel, 'details': details});
  }

  allResults.sort((a, b) => ((b['best'] as double?) ?? -999999).compareTo((a['best'] as double?) ?? -999999));
  print('\n\n========== 10개 신규 종목 결과 ==========');
  int win = 0, lose = 0;
  for (final r in allResults) {
    final b = r['best'] as double;
    if (b >= 0) win++; else lose++;
    print('${b >= 0 ? "✅" : "❌"} ${r["code"]} ${r["name"]}: ${b >= 0 ? "+" : ""}${b.toStringAsFixed(0)}원 (${r["bestLabel"]})');
  }
  print('\n✅ 수익: $win개  ❌ 손실: $lose개');
  File('$cacheDir\\new10_results.json').writeAsStringSync(jsonEncode(allResults));
  print('저장: $cacheDir\\new10_results.json');
}

// ---- 의존성 없는 경량 VWAP Cross + RSI 백테스트 ----
Map<String, dynamic> _runBT(List<Map<String, dynamic>> candles, double ts,
    double entry, bool useRsi, double ob, double os) {
  final close = candles.map((c) => (c['c'] as num).toDouble()).toList();
  if (close.length < 30) return {'net': 0.0, 'trades': 0, 'winRate': 0.0};

  // VWAP
  double cumTpv = 0, cumVol = 0;
  final vwap = <double>[];
  for (final c in candles) {
    final tp = ((c['h'] as num) + (c['l'] as num) + (c['c'] as num)) / 3;
    cumTpv += tp * (c['v'] as num).toDouble(); cumVol += (c['v'] as num).toDouble();
    vwap.add(cumTpv / cumVol);
  }

  // RSI
  List<double>? rsi;
  if (useRsi) {
    rsi = []; final ch = <double>[];
    for (int i = 1; i < close.length; i++) ch.add(close[i] - close[i-1]);
    rsi.addAll(List.filled(close.length, 50.0));
    double ag = 0, al = 0;
    for (int i = 0; i < 14 && i < ch.length; i++) { if (ch[i] > 0) ag += ch[i]; else al -= ch[i]; }
    ag /= 14; al /= 14;
    if (al == 0) rsi[14] = 100; else if (ag == 0) rsi[14] = 0; else rsi[14] = 100 - 100 / (1 + ag / al);
    for (int i = 15; i < close.length; i++) {
      final g = ch[i-1] > 0 ? ch[i-1] : 0, l = ch[i-1] < 0 ? -ch[i-1] : 0;
      ag = (ag * 13 + g) / 14; al = (al * 13 + l) / 14;
      rsi[i] = al == 0 ? 100 : (ag == 0 ? 0 : 100 - 100 / (1 + ag / al));
    }
  }

  double ep = 0; bool inPos = false, isLong = false;
  int trades = 0, wins = 0; double netPnl = 0;
  for (int i = 1; i < close.length; i++) {
    if (!inPos) {
      if (close[i-1] <= vwap[i-1] && close[i] > vwap[i]) { isLong = true; ep = close[i]; inPos = true; }
      else if (close[i-1] >= vwap[i-1] && close[i] < vwap[i]) { isLong = false; ep = close[i]; inPos = true; }
      if (!inPos) continue;
      if (entry > 0 && (close[i] - vwap[i]).abs() < entry * ts) { inPos = false; continue; }
      if (useRsi && i < (rsi?.length ?? 0)) {
        if ((isLong && (rsi![i] > ob)) || (!isLong && (rsi![i] < os))) { inPos = false; continue; }
      }
    } else {
      final exit = (isLong && close[i] < vwap[i]) || (!isLong && close[i] > vwap[i]);
      if (!exit && i < close.length - 1) continue;
      final pnl = isLong ? close[i] - ep : ep - close[i];
      final comm = (ep + close[i]) * 0.00147;
      netPnl += pnl - comm; trades++;
      if (pnl - comm > 0) wins++;
      inPos = false;
    }
  }
  return {'net': netPnl, 'trades': trades, 'winRate': trades > 0 ? wins / trades : 0.0};
}

Future<List<Map<String, dynamic>>> _downloadMinute(
    String token, String key, String secret, String baseUrl,
    String code, DateTime start, DateTime end) async {
  final all = <Map<String, dynamic>>[];
  for (int d = 0; d <= end.difference(start).inDays; d++) {
    final date = start.add(Duration(days: d));
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
    final chunks = await Future.wait(['093000','113000','133000','153000'].map((t) =>
      _fetchChunk(token, key, secret, baseUrl, code, date, t)));
    final seen = <String>{};
    for (final chunk in chunks) {
      for (final c in chunk) if (seen.add(c['t'] as String)) all.add(c);
    }
    if (d % 30 == 0) print('  ${d}/${end.difference(start).inDays}일 (${all.length}캔들)');
    await Future.delayed(const Duration(milliseconds: 80));
  }
  return all;
}

Future<List<Map<String, dynamic>>> _fetchChunk(
    String token, String key, String secret, String baseUrl,
    String code, DateTime date, String startTime) async {
  final ds = '${date.year}${date.month.toString().padLeft(2,'0')}${date.day.toString().padLeft(2,'0')}';
  final c = HttpClient();
  try {
    final r = await c.getUrl(Uri.parse(
      '$baseUrl/uapi/domestic-stock/v1/quotations/inquire-time-dailychartprice'
      '?FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=$code&FID_INPUT_HOUR_1=$startTime&FID_INPUT_DATE_1=$ds'
      '&FID_PW_DATA_INCU_YN=Y&FID_FAKE_TICK_INCU_YN=N'));
    r.headers.set('Content-Type','application/json'); r.headers.set('authorization','Bearer $token');
    r.headers.set('appkey',key); r.headers.set('appsecret',secret);
    r.headers.set('custtype','P'); r.headers.set('tr_id','FHKST03010230');
    final res = await r.close(); final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['rt_cd'] != '0') return [];
    return ((json['output2'] as List<dynamic>?) ?? []).map((e) => {
      't':'${ds}T${(e as Map)['stck_cntg_hour']}',
      'o':double.parse(e['stck_oprc'] as String),'h':double.parse(e['stck_hgpr'] as String),
      'l':double.parse(e['stck_lwpr'] as String),'c':double.parse(e['stck_prpr'] as String),
      'v':double.parse(e['cntg_vol'] as String),
    }).toList();
  } catch (_) { return []; } finally { c.close(); }
}

List<Map<String, dynamic>>? _loadCached(String dir, String symbol) {
  final d = Directory(dir); if (!d.existsSync()) return null;
  final files = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_${symbol}_') && f.path.endsWith('_1d.json')).toList();
  if (files.isEmpty) return null;
  files.sort((a,b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return (jsonDecode(files.first.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();
}

void _saveCandles(String dir, String symbol, DateTime start, DateTime end, List<Map<String,dynamic>> candles) {
  if (candles.isEmpty) return;
  candles.sort((a,b) => (a['t'] as String).compareTo(b['t'] as String));
  final sf = '${start.year}${start.month.toString().padLeft(2,'0')}${start.day.toString().padLeft(2,'0')}';
  final ef = '${end.year}${end.month.toString().padLeft(2,'0')}${end.day.toString().padLeft(2,'0')}';
  File('$dir\\candle_${symbol}_${sf}${ef}_1d.json').writeAsStringSync(jsonEncode(candles));
}

double _detectTickSize(List<Map<String,dynamic>> candles) {
  double sum = 0; for (final c in candles) sum += (c['c'] as num).toDouble();
  final avg = sum / candles.length;
  if (avg >= 100000) return 100; if (avg >= 10000) return 50; if (avg >= 5000) return 10;
  return 5;
}

Future<String> _getToken(String key, String secret, String baseUrl) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    r.headers.set('Content-Type','application/json');
    r.write(jsonEncode({'grant_type':'client_credentials','appkey':key,'appsecret':secret}));
    final res = await r.close(); final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String,dynamic>;
    if (j['access_token'] == null) { print('토큰 발급 실패: ${j['msg1'] ?? j['error_description'] ?? body}'); return ''; }
    return j['access_token'] as String;
  } finally { c.close(); }
}
