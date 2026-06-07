import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  // CLI args
  double principal = 10000000;
  double maxPrice = 0; // 0 = no limit
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--principal' && i + 1 < args.length) principal = double.tryParse(args[i+1]) ?? principal;
    if (args[i].startsWith('--principal=')) principal = double.tryParse(args[i].substring(12)) ?? principal;
    if (args[i] == '--maxPrice' && i + 1 < args.length) maxPrice = double.tryParse(args[i+1]) ?? maxPrice;
    if (args[i].startsWith('--maxPrice=')) maxPrice = double.tryParse(args[i].substring(11)) ?? maxPrice;
  }

  final allStocks = [..._kospiStocks(), ..._kosdaqStocks()];

  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 25)); // 20~25영업일치
  final results = <Map<String, dynamic>>[];

  print('=== KOSPI 일일 스크리닝 ===');
  print('대상: ${allStocks.length}개 종목');
  print('기간: ${start.toIso8601String().substring(0,10)} ~ ${now.toIso8601String().substring(0,10)}\n');

  for (int i = 0; i < allStocks.length; i++) {
    final s = allStocks[i];
    if (i % 10 == 0) print('${i}/${allStocks.length} (적합 ${results.where((r)=>r['grade']=='적합').length}/${results.length})...');

    final candles = await _fetchDaily(token, appKey, appSecret, baseUrl, s['code']!, start, now);
    if (candles.length < 10) continue;

    // maxPrice 필터
    final lastPrice = (candles.last['c'] as num).toDouble();
    if (maxPrice > 0 && lastPrice > maxPrice) continue;

    final score = _evaluate(candles, s['code']!, principal);
    if (score['score'] is int && (score['score'] as int) > 0) {
      results.add({'code': s['code'], 'name': s['name'], 'price': lastPrice, ...score});
    }

    await Future.delayed(const Duration(milliseconds: 100));
  }

  results.sort((a, b) => ((b['score'] as int?) ?? 0).compareTo((a['score'] as int?) ?? 0));

  // MD 저장
  final md = _buildMd(results, now, principal, maxPrice);
  File('$cacheDir\\daily_screen.md').writeAsStringSync(md);
  print('\n저장: $cacheDir\\daily_screen.md');

  // 콘솔 출력
  print('\n=== ${now.toIso8601String().substring(0,10)} TOP 스크리닝 ===');
  print('적합: ${results.where((r) => r['grade'] == '적합').length}개 / 관심: ${results.where((r) => r['grade'] == '관심').length}개\n');
  for (final r in results.take(20)) {
    final g = r['grade'] as String;
    final icon = g == '적합' ? '🟢' : (g == '관심' ? '🟡' : '⚪');
    print('$icon [${r['score']}] ${r['code']} ${r['name']}: ${r['trend']} (CI:${(r['ci'] as double).toStringAsFixed(0)}, 이탈:${r['distTicks']}틱)');
  }
}

int _weekdaysBetween(DateTime a, DateTime b) {
  int count = 0;
  for (int i = 0; i <= b.difference(a).inDays; i++) {
    final d = a.add(Duration(days: i));
    if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
  }
  return count;
}

Map<String, dynamic> _evaluate(List<Map<String, dynamic>> candles, String code, double principal) {
  final close = candles.map((c) => (c['c'] as num).toDouble()).toList();
  final high = candles.map((c) => (c['h'] as num).toDouble()).toList();
  final low = candles.map((c) => (c['l'] as num).toDouble()).toList();
  if (close.length < 10) return {'score': 0, 'grade': '부족'};

  // VWAP
  double cumTpv = 0, cumVol = 0;
  final vwap = <double>[];
  for (int i = 0; i < close.length; i++) {
    final tp = (high[i] + low[i] + close[i]) / 3;
    cumTpv += tp * (candles[i]['v'] as num).toDouble();
    cumVol += (candles[i]['v'] as num).toDouble();
    vwap.add(cumTpv / cumVol);
  }

  // VWAP 기울기 (최근 10일)
  final vwapSlope = vwap.length > 10 ? (vwap.last - vwap[vwap.length - 11]) / 10 / vwap[vwap.length - 11] * 100 : 0.0;
  final trend = vwapSlope > 0.2 ? '상승' : (vwapSlope < -0.2 ? '하락' : '횡보');

  // CI (14)
  final ci = _calcCi(high, low, close);

  // 현재가 VWAP 이탈 거리 (틱)
  final tickPrice = _tickSize(close);
  final distTicks = ((close.last - vwap.last).abs() / tickPrice).round();

  // 과거 1년 테스트 결과 확인 (선택)
  final known = _knownResults[code];
  final histReturn = known?['net'] as int? ?? 0;
  final histGrade = known?['grade'] as String? ?? '';

  // 종합 점수 (0~10), principal 반영
  int score = 0;
  final pnlRatio = histReturn > 0 && principal > 0 ? histReturn / principal : histReturn / 10000000;
  if (pnlRatio > 0.5) score += 4;    // +50% 이상
  else if (pnlRatio > 0.1) score += 3; // +10%~50%
  else if (pnlRatio > 0) score += 2;
  else if (histGrade.isNotEmpty) score -= 2;

  if (ci < 45) score += 3;
  else if (ci < 52) score += 1;
  else score -= 1;

  if (trend == '상승') score += 2;
  else if (trend == '하락') score -= 1;

  if (distTicks >= 3 && distTicks <= 20) score += 1; // 적정 이탈
  if (vwapSlope.abs() > 0.5) score += 1; // 강한 추세

  // 등급
  String grade;
  if (score >= 7) grade = '적합';
  else if (score >= 4) grade = '관심';
  else grade = '부적합';

  return {
    'score': score, 'grade': grade, 'trend': trend,
    'ci': ci, 'distTicks': distTicks, 'vwapSlope': vwapSlope,
    'histReturn': histReturn, 'histGrade': histGrade,
  };
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
  if (avg >= 100000) return 100;
  if (avg >= 10000) return 50;
  if (avg >= 5000) return 10;
  return 5;
}

String _buildMd(List<Map<String, dynamic>> results, DateTime now, double principal, double maxPrice) {
  final b = StringBuffer();
  b.writeln('# KOSPI 일일 스크리닝 리포트');
  b.writeln();
  b.writeln('**생성일:** ${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}');
b.writeln('**대상:** KOSPI + KOSDAQ (stock_db 기준)');
b.writeln('**조건:** 20일 일봉 VWAP + CI + 추세 분석, maxPrice 필터');
b.writeln('**원금:** ${principal.toStringAsFixed(0)}원');
if (maxPrice > 0) b.writeln('**최대 주가:** ${maxPrice.toStringAsFixed(0)}원');
  b.writeln();

  final suit = results.where((r) => r['grade'] == '적합').toList();
  final watch = results.where((r) => r['grade'] == '관심').toList();

  b.writeln('## ✅ 매매 적합 (${suit.length}개)');
  b.writeln();
  b.writeln('| 순위 | 코드 | 종목 | 점수 | 추세 | CI | 이탈틱 | 연간수익 | 현재가 |');
  b.writeln('|------|------|------|------|------|-----|--------|---------|--------|');
  for (int i = 0; i < suit.length; i++) {
    final r = suit[i];
    final hr = r['histReturn'] as int;
    final hs = hr >= 0 ? '+' : '';
      final price = (r['price'] as double?) ?? 0;
      b.writeln('| ${i+1} | ${r['code']} | ${r['name']} | ${r['score']} | ${r['trend']} | ${(r['ci'] as double).toStringAsFixed(0)} | ${r['distTicks']}틱 | ${hs}${hr}원 | ₩${price.toStringAsFixed(0)} |');
    }
    b.writeln();
    b.writeln('## 🟡 관심 종목 (${watch.length}개)');
    b.writeln();
    for (final r in watch) {
      final hr = r['histReturn'] as int;
      final hs = hr >= 0 ? '+' : '';
      final price = (r['price'] as double?) ?? 0;
      b.writeln('- ${r['code']} ${r['name']}: 점수 ${r['score']}, ${r['trend']}, CI:${(r['ci'] as double).toStringAsFixed(0)}, 이탈${r['distTicks']}틱, ₩${price.toStringAsFixed(0)}, 연간${hs}${hr}원');
    }

  return b.toString();
}

final Map<String, Map<String, dynamic>> _knownResults = {
  '000100': {'net': -126, 'grade': '부적합'},
  '000150': {'net': -6356, 'grade': '부적합'},
  '000270': {'net': -12404, 'grade': '부적합'},
  '000660': {'net': -4769, 'grade': '부적합'},
  '000810': {'net': -12543, 'grade': '부적합'},
  '000880': {'net': 38864, 'grade': '적합'},
  '001040': {'net': 61476, 'grade': '적합'},
  '002790': {'net': -11654, 'grade': '부적합'},
  '003490': {'net': 9707, 'grade': '적합'},
  '004020': {'net': -8442, 'grade': '부적합'},
  '005380': {'net': -4411, 'grade': '부적합'},
  '005490': {'net': 3638, 'grade': '적합'},
  '005930': {'net': -4314, 'grade': '부적합'},
  '005935': {'net': -10523, 'grade': '부적합'},
  '006400': {'net': -4294, 'grade': '부적합'},
  '009150': {'net': 10599, 'grade': '적합'},
  '009540': {'net': -255, 'grade': '부적합'},
  '010130': {'net': 39619, 'grade': '적합'},
  '010140': {'net': 14395, 'grade': '적합'},
  '010620': {'net': 8966, 'grade': '적합'},
  '011170': {'net': -4006, 'grade': '부적합'},
  '011200': {'net': 7273, 'grade': '적합'},
  '012330': {'net': -5218, 'grade': '부적합'},
  '016360': {'net': -1200, 'grade': '부적합'},
  '017670': {'net': -3214, 'grade': '부적합'},
  '018260': {'net': -6132, 'grade': '부적합'},
  '018290': {'net': -3703, 'grade': '부적합'},
  '021240': {'net': -6917, 'grade': '부적합'},
  '024110': {'net': -828, 'grade': '부적합'},
  '028260': {'net': -5401, 'grade': '부적합'},
  '030200': {'net': -5422, 'grade': '부적합'},
  '032580': {'net': 5779, 'grade': '적합'},
  '032830': {'net': 9325, 'grade': '적합'},
  '034020': {'net': 450, 'grade': '적합'},
  '034730': {'net': 10764, 'grade': '적합'},
  '036570': {'net': -2595, 'grade': '부적합'},
  '041510': {'net': -4105, 'grade': '부적합'},
  '042660': {'net': -7232, 'grade': '부적합'},
  '042700': {'net': -6404, 'grade': '부적합'},
  '047050': {'net': -8531, 'grade': '부적합'},
  '047810': {'net': 14593, 'grade': '적합'},
  '051360': {'net': 2934, 'grade': '적합'},
  '051910': {'net': -723, 'grade': '부적합'},
  '052790': {'net': -372, 'grade': '부적합'},
  '055550': {'net': -36, 'grade': '부적합'},
  '063160': {'net': 248, 'grade': '적합'},
  '065350': {'net': -18838, 'grade': '부적합'},
  '066570': {'net': -11095, 'grade': '부적합'},
  '067160': {'net': 4549, 'grade': '적합'},
  '068270': {'net': -2206, 'grade': '부적합'},
  '069080': {'net': 15929, 'grade': '적합'},
  '071050': {'net': 5915, 'grade': '적합'},
  '086280': {'net': -4857, 'grade': '부적합'},
  '086790': {'net': 22739, 'grade': '적합'},
  '086900': {'net': -2516, 'grade': '부적합'},
  '088350': {'net': -17126, 'grade': '부적합'},
  '090430': {'net': -6776, 'grade': '부적합'},
  '095340': {'net': 41611, 'grade': '적합'},
  '096770': {'net': 194, 'grade': '적합'},
  '097950': {'net': 8092, 'grade': '적합'},
  '105560': {'net': 2706, 'grade': '적합'},
  '112040': {'net': 45047, 'grade': '적합'},
  '115180': {'net': 44155, 'grade': '적합'},
  '128940': {'net': 34564, 'grade': '적합'},
  '138930': {'net': -5443, 'grade': '부적합'},
  '145020': {'net': 42251, 'grade': '적합'},
  '196170': {'net': 3883, 'grade': '적합'},
  '207940': {'net': -4593, 'grade': '부적합'},
  '214150': {'net': -3347, 'grade': '부적합'},
  '241560': {'net': -9702, 'grade': '부적합'},
  '247540': {'net': 12238, 'grade': '적합'},
  '251270': {'net': 25246, 'grade': '적합'},
  '256840': {'net': 46459, 'grade': '적합'},
  '259960': {'net': -2825, 'grade': '부적합'},
  '263750': {'net': -9385, 'grade': '부적합'},
  '267250': {'net': -6280, 'grade': '부적합'},
  '277810': {'net': -4370, 'grade': '부적합'},
  '293490': {'net': -3433, 'grade': '부적합'},
  '316140': {'net': -3684, 'grade': '부적합'},
  '323410': {'net': 54196, 'grade': '적합'},
  '329180': {'net': -10406, 'grade': '부적합'},
  '340570': {'net': -3696, 'grade': '부적합'},
  '348370': {'net': -12721, 'grade': '부적합'},
  '352820': {'net': -5040, 'grade': '부적합'},
  '373220': {'net': -3612, 'grade': '부적합'},
  '377300': {'net': 129387, 'grade': '적합'},
  '402340': {'net': 62825, 'grade': '적합'},
  '403870': {'net': -9790, 'grade': '부적합'},
};

Future<String> _getToken(String key, String secret, String baseUrl) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('$baseUrl/oauth2/tokenP'));
    r.headers.set('Content-Type', 'application/json');
    r.write(jsonEncode({'grant_type': 'client_credentials', 'appkey': key, 'appsecret': secret}));
    final res = await r.close();
    final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['access_token'] == null) { print('토큰 발급 실패: ${j['msg1']??j['error_description']??body}'); return ''; }
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
    final res = await r.close();
    final body = await res.transform(utf8.decoder).join();
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

List<Map<String, String>> _kospiStocks() {
  return [
    {'code': '005930', 'name': '삼성전자'}, {'code': '000660', 'name': 'SK하이닉스'},
    {'code': '005935', 'name': '삼성전자우'}, {'code': '373220', 'name': 'LG에너지솔루션'},
    {'code': '207940', 'name': '삼성바이오로직스'}, {'code': '005380', 'name': '현대차'},
    {'code': '000270', 'name': '기아'}, {'code': '068270', 'name': '셀트리온'},
    {'code': '105560', 'name': 'KB금융'}, {'code': '055550', 'name': '신한지주'},
    {'code': '005490', 'name': 'POSCO홀딩스'}, {'code': '012330', 'name': '현대모비스'},
    {'code': '003490', 'name': '대한항공'}, {'code': '018260', 'name': '삼성에스디에스'},
    {'code': '323410', 'name': '카카오뱅크'}, {'code': '377300', 'name': '카카오페이'},
    {'code': '086790', 'name': '하나금융지주'}, {'code': '138930', 'name': 'BNK금융지주'},
    {'code': '316140', 'name': '우리금융지주'}, {'code': '024110', 'name': '기업은행'},
    {'code': '002790', 'name': '아모레G'}, {'code': '090430', 'name': '아모레퍼시픽'},
    {'code': '036570', 'name': '엔씨소프트'}, {'code': '251270', 'name': '넷마블'},
    {'code': '259960', 'name': '크래프톤'}, {'code': '066570', 'name': 'LG전자'},
    {'code': '006400', 'name': '삼성SDI'}, {'code': '010130', 'name': '고려아연'},
    {'code': '000810', 'name': '삼성화재'}, {'code': '030200', 'name': 'KT'},
    {'code': '017670', 'name': 'SK텔레콤'}, {'code': '034730', 'name': 'SK'},
    {'code': '096770', 'name': 'SK이노베이션'}, {'code': '011170', 'name': '롯데케미칼'},
    {'code': '051910', 'name': 'LG화학'}, {'code': '028260', 'name': '삼성물산'},
    {'code': '042660', 'name': '한화오션'}, {'code': '000880', 'name': '한화'},
    {'code': '086280', 'name': '현대글로비스'}, {'code': '329180', 'name': 'HD현대중공업'},
    {'code': '267250', 'name': 'HD현대'}, {'code': '009540', 'name': 'HD한국조선해양'},
    {'code': '047050', 'name': '포스코인터내셔널'}, {'code': '128940', 'name': '한미약품'},
    {'code': '047810', 'name': '한국항공우주'}, {'code': '021240', 'name': '코웨이'},
    {'code': '010140', 'name': '삼성중공업'}, {'code': '009150', 'name': '삼성전기'},
    {'code': '011200', 'name': 'HMM'}, {'code': '241560', 'name': '두산밥캣'},
    {'code': '000150', 'name': '두산'}, {'code': '034020', 'name': '두산에너빌리티'},
    {'code': '402340', 'name': 'SK스퀘어'}, {'code': '352820', 'name': '하이브'},
    {'code': '004020', 'name': '현대제철'}, {'code': '010620', 'name': '현대미포조선'},
    {'code': '071050', 'name': '한국금융지주'}, {'code': '016360', 'name': '삼성증권'},
    {'code': '032830', 'name': '삼성생명'}, {'code': '088350', 'name': '한화생명'},
    {'code': '063160', 'name': '종근당'}, {'code': '000100', 'name': '유한양행'},
    {'code': '001040', 'name': 'CJ'},     {'code': '097950', 'name': 'CJ제일제당'},
  ];
}

List<Map<String, String>> _kosdaqStocks() => [
  {'code': '247540', 'name': '에코프로비엠'},
  {'code': '196170', 'name': '알테오젠'},
  {'code': '091990', 'name': '셀트리온헬스케어'},
  {'code': '348370', 'name': '엘앤에프'},
  {'code': '263750', 'name': '펄어비스'},
  {'code': '112040', 'name': '위메이드'},
  {'code': '095340', 'name': 'ISC'},
  {'code': '214150', 'name': '클래시스'},
  {'code': '145020', 'name': '휴젤'},
  {'code': '042700', 'name': '한미반도체'},
  {'code': '277810', 'name': '레인보우로보틱스'},
  {'code': '293490', 'name': '카카오게임즈'},
  {'code': '067160', 'name': '아프리카TV'},
  {'code': '403870', 'name': 'HPSP'},
  {'code': '340570', 'name': '티웨이항공'},
  {'code': '065350', 'name': '신성델타테크'},
  {'code': '018290', 'name': '브이티'},
  {'code': '115180', 'name': '큐리옥스'},
  {'code': '256840', 'name': '한국파마'},
  {'code': '069080', 'name': '웹젠'},
  {'code': '086900', 'name': '메디톡스'},
  {'code': '041510', 'name': '에스엠'},
  {'code': '052790', 'name': '액토즈소프트'},
  {'code': '900280', 'name': '골든센츄리'},
  {'code': '051360', 'name': '토비스'},
  {'code': '032580', 'name': '피델릭스'},
];
