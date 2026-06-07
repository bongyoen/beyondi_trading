import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// 90개 종목 분봉 데이터 다운로드 (timeout 이슈 방지를 위해 small batch)
/// 실행: dart run bin/download_all.dart
void main(List<String> args) async {
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final configFile = File('$cacheDir\\kis_config.json');
  if (!configFile.existsSync()) { print('kis_config.json 없음'); exit(1); }
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final appKey = config['app_key'] as String;
  final appSecret = config['app_secret'] as String;
  final isPaper = appKey.startsWith('PS') ? true : ((config['is_paper'] as bool?) ?? true);
  final baseUrl = isPaper ? 'https://openapivts.koreainvestment.com:29443' : 'https://openapi.koreainvestment.com:9443';

  final tokenFile = File('$cacheDir\\kis_token.txt');
  var token = tokenFile.existsSync() ? tokenFile.readAsStringSync().trim() : '';
  if (token.isEmpty) {
    token = await _getToken(appKey, appSecret, baseUrl);
    if (token.isEmpty) { print('토큰 발급 실패'); exit(1); }
    tokenFile.writeAsStringSync(token);
  }

  final allStocks = [..._kospiStocks(), ..._kosdaqStocks()];
  final end = DateTime.now();
  final start = DateTime(end.year - 1, end.month, end.day);

  int dl = 0, skip = 0;
  for (int i = 0; i < allStocks.length; i++) {
    final s = allStocks[i];
    final code = s['code'] as String;
    final name = s['name'] as String;

    // 캐시 확인
    final existing = _loadCached(cacheDir, code);
    if (existing != null && existing.length > 500) { skip++; continue; }

    dl++;
    print('[$dl] ${i+1}/${allStocks.length} $code $name');
    final candles = await _downloadMinute(token, appKey, appSecret, baseUrl, code, start, end);
    if (candles.length > 500) {
      _saveCandles(cacheDir, code, start, end, candles);
      print('  ✓ ${candles.length}캔들');
    } else {
      print('  ✗ 데이터 부족 (${candles.length})');
    }
  }

  print('\n=== 완료 ===');
  print('다운로드: $dl개 / 스킵(기존): $skip개 / 전체: ${allStocks.length}개');
}

// ---- 종목 리스트 ----
List<Map<String, String>> _kospiStocks() => [
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
];
List<Map<String, String>> _kosdaqStocks() => [
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

// ---- KIS API + 캐시 관리 ----
Future<String> _getToken(String key, String secret, String baseUrl) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    r.headers.set('Content-Type', 'application/json');
    r.write(jsonEncode({'grant_type':'client_credentials','appkey':key,'appsecret':secret}));
    final res = await r.close(); final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['access_token'] == null) { print('토큰 실패: ${j['msg1']??j['error_description']??body}'); return ''; }
    return j['access_token'] as String;
  } finally { c.close(); }
}

Future<List<Map<String, dynamic>>> _fetchChunk(String token, String key, String secret, String baseUrl,
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
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['rt_cd'] != '0') return [];
    return ((j['output2'] as List<dynamic>?) ?? []).map((e) => {
      't':'${ds}T${(e as Map)['stck_cntg_hour']}',
      'o':double.parse(e['stck_oprc'] as String),'h':double.parse(e['stck_hgpr'] as String),
      'l':double.parse(e['stck_lwpr'] as String),'c':double.parse(e['stck_prpr'] as String),
      'v':double.parse(e['cntg_vol'] as String),
    }).toList();
  } catch (_) { return []; } finally { c.close(); }
}

Future<List<Map<String, dynamic>>> _downloadMinute(String token, String key, String secret, String baseUrl,
    String code, DateTime start, DateTime end) async {
  final all = <Map<String, dynamic>>[];
  for (int d = 0; d <= end.difference(start).inDays; d++) {
    final date = start.add(Duration(days: d));
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
    final chunks = await Future.wait(['093000','113000','133000','153000'].map((t) =>
      _fetchChunk(token, key, secret, baseUrl, code, date, t)));
    final seen = <String>{};
    for (final chunk in chunks) { for (final c in chunk) if (seen.add(c['t'] as String)) all.add(c); }
    if (d % 30 == 0) print('  ${d}/${end.difference(start).inDays}일 (${all.length}캔들)');
    await Future.delayed(const Duration(milliseconds: 80));
  }
  return all;
}

List<Map<String, dynamic>>? _loadCached(String dir, String symbol) {
  final d = Directory(dir); if (!d.existsSync()) return null;

  // _full_ 파일 우선
  final fullFile = File('$dir\\candle_${symbol}_full_1d.json');
  if (fullFile.existsSync()) {
    return (jsonDecode(fullFile.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // 구형 파일 스캔 → _full_로 마이그레이션
  final oldFiles = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_${symbol}_') && !f.path.contains('_full_') && f.path.endsWith('_1d.json')).toList();
  if (oldFiles.isEmpty) return null;
  oldFiles.sort((a,b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
  existing.sort((a,b) => (a['t'] as String).compareTo(b['t'] as String));
  final seen = <String>{};
  existing.retainWhere((e) => seen.add(e['t'] as String));
  file.writeAsStringSync(jsonEncode(existing));
}
