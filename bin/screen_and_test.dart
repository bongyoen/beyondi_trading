import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// daily_screen 점수 + Long Only 배치 결과 합성 리포트
void main(List<String> args) async {
  final cacheDir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';

  // 1. Long Only 배치 결과 로드
  final batchFile = File('$cacheDir\\batch_results_longonly.json');
  if (!batchFile.existsSync()) { print('batch_results_longonly.json 없음'); exit(1); }
  final batchResults = jsonDecode(batchFile.readAsStringSync()) as List<dynamic>;

  // 2. API 준비
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

  final start = DateTime.now().subtract(const Duration(days: 25));
  final end = DateTime.now();
  final names = {
    '005930':'삼성전자','000660':'SK하이닉스','005935':'삼성전자우','373220':'LG에너지솔루션',
    '207940':'삼성바이오로직스','005380':'현대차','000270':'기아','068270':'셀트리온',
    '105560':'KB금융','055550':'신한지주','005490':'POSCO홀딩스','012330':'현대모비스',
    '003490':'대한항공','018260':'삼성에스디에스','323410':'카카오뱅크','377300':'카카오페이',
    '086790':'하나금융지주','138930':'BNK금융지주','316140':'우리금융지주','024110':'기업은행',
    '002790':'아모레G','090430':'아모레퍼시픽','036570':'엔씨소프트','251270':'넷마블',
    '259960':'크래프톤','066570':'LG전자','006400':'삼성SDI','010130':'고려아연',
    '000810':'삼성화재','030200':'KT','017670':'SK텔레콤','034730':'SK',
    '096770':'SK이노베이션','011170':'롯데케미칼','051910':'LG화학','028260':'삼성물산',
    '042660':'한화오션','000880':'한화','086280':'현대글로비스','329180':'HD현대중공업',
    '267250':'HD현대','009540':'HD한국조선해양','047050':'포스코인터내셔널','128940':'한미약품',
    '047810':'한국항공우주','021240':'코웨이','010140':'삼성중공업','009150':'삼성전기',
    '011200':'HMM','241560':'두산밥캣','000150':'두산','034020':'두산에너빌리티',
    '402340':'SK스퀘어','352820':'하이브','004020':'현대제철','010620':'현대미포조선',
    '071050':'한국금융지주','016360':'삼성증권','032830':'삼성생명','088350':'한화생명',
    '063160':'종근당','000100':'유한양행','001040':'CJ','097950':'CJ제일제당',
    '247540':'에코프로비엠','196170':'알테오젠','091990':'셀트리온헬스케어','348370':'엘앤에프',
    '263750':'펄어비스','112040':'위메이드','095340':'ISC','214150':'클래시스',
    '145020':'휴젤','042700':'한미반도체','277810':'레인보우로보틱스','293490':'카카오게임즈',
    '067160':'아프리카TV','403870':'HPSP','340570':'티웨이항공','065350':'신성델타테크',
    '018290':'브이티','115180':'큐리옥스','256840':'한국파마','069080':'웹젠',
    '086900':'메디톡스','041510':'에스엠','052790':'액토즈소프트','900280':'골든센츄리',
    '051360':'토비스','032580':'피델릭스',
  };
  final known = {'377300':129387,'402340':62825,'001040':61476,'323410':54196,'256840':46459,'112040':45047,'115180':44155,'145020':42251,'095340':41611,'010130':39619,'000880':38864,'128940':34564,'251270':25246,'086790':22739,'069080':15929,'047810':14593,'010140':14395,'247540':12238,'034730':10764,'009150':10599,'003490':9707,'032830':9325,'010620':8966,'097950':8092,'011200':7273,'071050':5915,'032580':5779,'067160':4549,'196170':3883,'005490':3638,'051360':2934,'105560':2706,'034020':450,'063160':248,'096770':194};

  // 3. daily_screen 점수 계산
  print('일일 스크리닝 점수 계산 중...\n');
  final scored = <Map<String, dynamic>>[];
  int i = 0;
  for (final r in batchResults) {
    final code = r['code'] as String?;
    final batchNet = r['netReturn'] as num?;
    if (code == null || batchNet == null) continue;
    i++;

    final candles = await _fetchDaily(token, appKey, appSecret, baseUrl, code, start, end);
    if (candles.length < 10) continue;

    final score = _evaluate(candles, code, known[code] ?? 0);
    scored.add({
      'code': code,
      'name': names[code] ?? code,
      'score': score['score'],
      'grade': score['grade'],
      'trend': score['trend'],
      'ci': score['ci'],
      'distTicks': score['distTicks'],
      'batchNet': batchNet,
      'batchConfig': r['bestLabel'],
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (i % 10 == 0) print('$i/${batchResults.length}...');
  }

  // 4. 출력
  scored.sort((a, b) => ((b['score'] as int) - (b['batchNet'] as num) * 0).compareTo((a['score'] as int) - (a['batchNet'] as num) * 0));

  print('\n===== 전체 88종목: daily 점수 + Long Only 결과 =====\n');

  final high = scored.where((s) => (s['score'] as int) >= 7).toList();
  final mid = scored.where((s) => (s['score'] as int) >= 4 && (s['score'] as int) < 7).toList();
  final low = scored.where((s) => (s['score'] as int) < 4).toList();

  print('--- 점수 7↑ 적합 (${high.length}개) ---');
  for (final s in high) {
    final n = s['batchNet'] as num;
    final sn = n >= 0 ? '+' : '';
    print('  ${n >= 0 ? '✅' : '❌'} ${s['code']} ${s['name']}: 점수${s['score']} ${s['trend']} CI:${(s['ci'] as double).toStringAsFixed(0)} → LongOnly ${sn}${n.toStringAsFixed(0)}원');
  }

  print('\n--- 점수 4~6 관심 (${mid.length}개) ---');
  for (final s in mid.take(15)) {
    final n = s['batchNet'] as num;
    final sn = n >= 0 ? '+' : '';
    print('  ${n >= 0 ? '✅' : '❌'} ${s['code']} ${s['name']}: 점수${s['score']} ${s['trend']} → ${sn}${n.toStringAsFixed(0)}원');
  }
  if (mid.length > 15) print('  ...외 ${mid.length - 15}개');

  print('\n--- 점수 3↓ 부적합 (${low.length}개) ---');
  for (final s in low.take(10)) {
    final n = s['batchNet'] as num;
    final sn = n >= 0 ? '+' : '';
    print('  ${n >= 0 ? '✅' : '❌'} ${s['code']} ${s['name']}: 점수${s['score']} ${s['trend']} → ${sn}${n.toStringAsFixed(0)}원');
  }
  if (low.length > 10) print('  ...외 ${low.length - 10}개');

  // 5. 통계
  final highWin = high.where((s) => (s['batchNet'] as num) >= 0).length;
  final midWin = mid.where((s) => (s['batchNet'] as num) >= 0).length;
  final lowWin = low.where((s) => (s['batchNet'] as num) >= 0).length;

  print('\n===== 통계 =====');
  print('점수 7↑ (적합): ${high.length}개 → ${highWin}개 수익 (${(highWin/high.length*100).toStringAsFixed(0)}%)');
  print('점수 4~6 (관심): ${mid.length}개 → ${midWin}개 수익 (${(midWin/mid.length*100).toStringAsFixed(0)}%)');
  print('점수 3↓ (부적합): ${low.length}개 → ${lowWin}개 수익 (${(lowWin/low.length*100).toStringAsFixed(0)}%)');

  // 6. MD 저장
  _saveMd(scored, high, mid, low, cacheDir);
}

// ---- daily_screen scoring logic ----
Map<String, dynamic> _evaluate(List<Map<String, dynamic>> candles, String code, int histReturn) {
  final close = candles.map((c) => (c['c'] as num).toDouble()).toList();
  final high = candles.map((c) => (c['h'] as num).toDouble()).toList();
  final low = candles.map((c) => (c['l'] as num).toDouble()).toList();
  if (close.length < 10) return {'score': 0, 'grade': '부족'};

  double cumTpv = 0, cumVol = 0;
  final vwap = <double>[];
  for (int i = 0; i < close.length; i++) {
    final tp = (high[i] + low[i] + close[i]) / 3;
    cumTpv += tp * (candles[i]['v'] as num).toDouble();
    cumVol += (candles[i]['v'] as num).toDouble();
    vwap.add(cumTpv / cumVol);
  }

  final vwapSlope = vwap.length > 10 ? (vwap.last - vwap[vwap.length - 11]) / 10 / vwap[vwap.length - 11] * 100 : 0.0;
  final trend = vwapSlope > 0.2 ? '상승' : (vwapSlope < -0.2 ? '하락' : '횡보');
  final ci = _calcCi(high, low, close);
  final tickPrice = _tickSize(close);
  final distTicks = ((close.last - vwap.last).abs() / tickPrice).round();

  int score = 0;
  if (histReturn > 50000) score += 4;
  else if (histReturn > 10000) score += 3;
  else if (histReturn > 0) score += 2;
  else if (histReturn < 0) score -= 1;

  if (ci < 45) score += 3;
  else if (ci < 52) score += 1;
  else score -= 1;

  if (trend == '상승') score += 2;
  else if (trend == '하락') score -= 1;

  if (distTicks >= 3 && distTicks <= 20) score += 1;
  if (vwapSlope.abs() > 0.5) score += 1;

  String grade;
  if (score >= 7) grade = '적합';
  else if (score >= 4) grade = '관심';
  else grade = '부적합';

  return {'score': score, 'grade': grade, 'trend': trend, 'ci': ci, 'distTicks': distTicks};
}

double _calcCi(List<double> h, List<double> l, List<double> c) {
  if (h.length < 15) return 50;
  final tr = <double>[];
  tr.add(h[0] - l[0]);
  for (int i = 1; i < h.length; i++) {
    tr.add([h[i]-l[i], (h[i]-c[i-1]).abs(), (l[i]-c[i-1]).abs()].reduce((a,b)=>a>b?a:b));
  }
  final recent = h.length - 14;
  double sumTr = 0;
  for (int i = recent; i < h.length; i++) sumTr += tr[i];
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

void _saveMd(List<Map<String,dynamic>> all, List<Map<String,dynamic>> high, List<Map<String,dynamic>> mid, List<Map<String,dynamic>> low, String dir) {
  final b = StringBuffer();
  b.writeln('# 스크리닝 점수 + Long Only 통합 리포트');
  b.writeln('\n**생성일:** ${DateTime.now().toIso8601String().substring(0,10)}');
  b.writeln('**조건:** daily_screen 20일 점수 + Long Only + hybrid + 손절 3단계\n');

  final highWin = high.where((s) => (s['batchNet'] as num) >= 0).length;
  final midWin = mid.where((s) => (s['batchNet'] as num) >= 0).length;
  final lowWin = low.where((s) => (s['batchNet'] as num) >= 0).length;

  b.writeln('## 통계');
  b.writeln('| 점수대 | 개수 | 수익 | 비율 |');
  b.writeln('|--------|------|------|------|');
  b.writeln('| 점수 7↑ (적합) | ${high.length} | $highWin | ${(highWin/(high.length+1)*100).toStringAsFixed(0)}% |');
  b.writeln('| 점수 4~6 (관심) | ${mid.length} | $midWin | ${(midWin/(mid.length+1)*100).toStringAsFixed(0)}% |');
  b.writeln('| 점수 3↓ (부적합) | ${low.length} | $lowWin | ${(lowWin/(low.length+1)*100).toStringAsFixed(0)}% |');
  b.writeln('| **전체** | ${all.length} | ${highWin+midWin+lowWin} | ${((highWin+midWin+lowWin)/(all.length+1)*100).toStringAsFixed(0)}% |');

  b.writeln('\n## ✅ 점수 7↑ 적합 종목 (Long Only 결과)');
  b.writeln('| 코드 | 종목 | 점수 | 추세 | CI | LongOnly | 설정 |');
  b.writeln('|------|------|------|------|-----|----------|------|');
  for (final s in high) {
    final n = s['batchNet'] as num;
    b.writeln('| ${s['code']} | ${s['name']} | ${s['score']} | ${s['trend']} | ${(s['ci'] as double).toStringAsFixed(0)} | ${n >= 0 ? "+" : ""}${n.toStringAsFixed(0)}원 | ${s['batchConfig']} |');
  }

  b.writeln('\n## 🟡 점수 4~6 관심 종목 (Long Only 결과)');
  for (final s in mid) {
    final n = s['batchNet'] as num;
    b.writeln('- ${s['code']} ${s['name']}: 점수${s['score']} ${s['trend']} → ${n >= 0 ? "+" : ""}${n.toStringAsFixed(0)}원');
  }

  b.writeln('\n## ❌ 점수 3↓ 부적합 종목 (Long Only 결과)');
  for (final s in low) {
    final n = s['batchNet'] as num;
    b.writeln('- ${s['code']} ${s['name']}: 점수${s['score']} ${s['trend']} → ${n >= 0 ? "+" : ""}${n.toStringAsFixed(0)}원');
  }

  File('$dir\\screen_score_report.md').writeAsStringSync(b.toString());
  // Also save to project ai_docs
  try { File('${Directory.current.path}\\ai_docs\\screen_score_report.md').writeAsStringSync(b.toString()); } catch (_) {}
  print('\n저장: $dir\\screen_score_report.md');
}

// ---- KIS API ----
Future<String> _getToken(String key, String secret, String baseUrl) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    r.headers.set('Content-Type','application/json');
    r.write(jsonEncode({'grant_type':'client_credentials','appkey':key,'appsecret':secret}));
    final res = await r.close(); final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['access_token'] == null) return '';
    return j['access_token'] as String;
  } finally { c.close(); }
}

Future<List<Map<String, dynamic>>> _fetchDaily(String token, String key, String secret, String baseUrl, String code, DateTime start, DateTime end) async {
  final c = HttpClient();
  try {
    final r = await c.getUrl(Uri.parse(
      '$baseUrl/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice'
      '?FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=$code'
      '&FID_INPUT_DATE_1=${start.year}${start.month.toString().padLeft(2,'0')}${start.day.toString().padLeft(2,'0')}'
      '&FID_INPUT_DATE_2=${end.year}${end.month.toString().padLeft(2,'0')}${end.day.toString().padLeft(2,'0')}'
      '&FID_PERIOD_DIV_CODE=D&FID_ORG_ADJ_PRC=0'));
    r.headers.set('Content-Type','application/json');
    r.headers.set('authorization','Bearer $token');
    r.headers.set('appkey',key); r.headers.set('appsecret',secret);
    r.headers.set('custtype','P'); r.headers.set('tr_id','FHKST03010100');
    final res = await r.close(); final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['rt_cd'] != '0') return [];
    return ((j['output2'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>().reversed.map((e) => {
      'c': double.parse((e as Map)['stck_clpr'] as String),
      'h': double.parse(e['stck_hgpr'] as String),
      'l': double.parse(e['stck_lwpr'] as String),
      'v': double.parse(e['acml_vol'] as String),
    }).toList();
  } finally { c.close(); }
}
