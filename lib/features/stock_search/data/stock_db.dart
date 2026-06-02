/// 주식 종목 데이터
class StockInfo {
  final String code;
  final String name;
  final String market; // 'KOSPI', 'KOSDAQ', 'NASDAQ', 'NYSE'

  const StockInfo(this.code, this.name, this.market);

  String get display => '$name ($code)';
}

// 초성 추출
String _cho(String text) {
  const cho = [
    'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];
  return text.split('').map((c) {
    final code = c.codeUnitAt(0);
    if (code >= 0xAC00 && code <= 0xD7A3) {
      return cho[(code - 0xAC00) ~/ 588];
    }
    return c;
  }).join();
}

// 종목 DB (주요 종목)
final List<StockInfo> stockDb = [
  // KOSPI
  const StockInfo('005930', '삼성전자', 'KOSPI'),
  const StockInfo('000660', 'SK하이닉스', 'KOSPI'),
  const StockInfo('005935', '삼성전자우', 'KOSPI'),
  const StockInfo('373220', 'LG에너지솔루션', 'KOSPI'),
  const StockInfo('207940', '삼성바이오로직스', 'KOSPI'),
  const StockInfo('005380', '현대차', 'KOSPI'),
  const StockInfo('000270', '기아', 'KOSPI'),
  const StockInfo('068270', '셀트리온', 'KOSPI'),
  const StockInfo('105560', 'KB금융', 'KOSPI'),
  const StockInfo('055550', '신한지주', 'KOSPI'),
  const StockInfo('005490', 'POSCO홀딩스', 'KOSPI'),
  const StockInfo('012330', '현대모비스', 'KOSPI'),
  const StockInfo('003490', '대한항공', 'KOSPI'),
  const StockInfo('018260', '삼성에스디에스', 'KOSPI'),
  const StockInfo('323410', '카카오뱅크', 'KOSPI'),
  const StockInfo('377300', '카카오페이', 'KOSPI'),
  const StockInfo('086790', '하나금융지주', 'KOSPI'),
  const StockInfo('138930', 'BNK금융지주', 'KOSPI'),
  const StockInfo('316140', '우리금융지주', 'KOSPI'),
  const StockInfo('024110', '기업은행', 'KOSPI'),
  const StockInfo('002790', '아모레G', 'KOSPI'),
  const StockInfo('090430', '아모레퍼시픽', 'KOSPI'),
  const StockInfo('036570', '엔씨소프트', 'KOSPI'),
  const StockInfo('251270', '넷마블', 'KOSPI'),
  const StockInfo('259960', '크래프톤', 'KOSPI'),
  const StockInfo('066570', 'LG전자', 'KOSPI'),
  const StockInfo('006400', '삼성SDI', 'KOSPI'),
  const StockInfo('010130', '고려아연', 'KOSPI'),
  const StockInfo('000810', '삼성화재', 'KOSPI'),
  const StockInfo('030200', 'KT', 'KOSPI'),
  const StockInfo('017670', 'SK텔레콤', 'KOSPI'),
  const StockInfo('034730', 'SK', 'KOSPI'),
  const StockInfo('096770', 'SK이노베이션', 'KOSPI'),
  const StockInfo('011170', '롯데케미칼', 'KOSPI'),
  const StockInfo('051910', 'LG화학', 'KOSPI'),
  const StockInfo('006260', 'LS', 'KOSPI'),
  const StockInfo('001040', 'CJ', 'KOSPI'),
  const StockInfo('097950', 'CJ제일제당', 'KOSPI'),
  const StockInfo('028260', '삼성물산', 'KOSPI'),
  const StockInfo('042660', '한화오션', 'KOSPI'),
  const StockInfo('000880', '한화', 'KOSPI'),
  const StockInfo('086280', '현대글로비스', 'KOSPI'),
  const StockInfo('329180', 'HD현대중공업', 'KOSPI'),
  const StockInfo('267250', 'HD현대', 'KOSPI'),
  const StockInfo('009540', 'HD한국조선해양', 'KOSPI'),
  const StockInfo('093370', '후성', 'KOSPI'),
  const StockInfo('047050', '포스코인터내셔널', 'KOSPI'),
  const StockInfo('128940', '한미약품', 'KOSPI'),
  const StockInfo('002380', 'KCC', 'KOSPI'),
  const StockInfo('047810', '한국항공우주', 'KOSPI'),
  const StockInfo('021240', '코웨이', 'KOSPI'),
  const StockInfo('010140', '삼성중공업', 'KOSPI'),
  const StockInfo('009150', '삼성전기', 'KOSPI'),
  const StockInfo('011200', 'HMM', 'KOSPI'),
  const StockInfo('180640', '한진칼', 'KOSPI'),
  const StockInfo('241560', '두산밥캣', 'KOSPI'),
  const StockInfo('000150', '두산', 'KOSPI'),
  const StockInfo('034020', '두산에너빌리티', 'KOSPI'),
  const StockInfo('402340', 'SK스퀘어', 'KOSPI'),
  const StockInfo('352820', '하이브', 'KOSPI'),
  const StockInfo('004020', '현대제철', 'KOSPI'),
  const StockInfo('010620', '현대미포조선', 'KOSPI'),
  const StockInfo('004990', '롯데지주', 'KOSPI'),
  const StockInfo('071050', '한국금융지주', 'KOSPI'),
  const StockInfo('016360', '삼성증권', 'KOSPI'),
  const StockInfo('086220', '동양생명', 'KOSPI'),
  const StockInfo('032830', '삼성생명', 'KOSPI'),
  const StockInfo('088350', '한화생명', 'KOSPI'),
  const StockInfo('063160', '종근당', 'KOSPI'),
  const StockInfo('000100', '유한양행', 'KOSPI'),
  const StockInfo('007070', 'GS리테일', 'KOSPI'),
  const StockInfo('004370', '농심', 'KOSPI'),
  const StockInfo('271560', '오리온', 'KOSPI'),
  const StockInfo('007310', '오뚜기', 'KOSPI'),
  const StockInfo('282330', 'BGF리테일', 'KOSPI'),
  const StockInfo('139480', '이마트', 'KOSPI'),
  const StockInfo('069080', '웹젠', 'KOSPI'),
  const StockInfo('112040', '위메이드', 'KOSPI'),

  // KOSDAQ
  const StockInfo('035420', 'NAVER', 'KOSDAQ'),
  const StockInfo('035720', '카카오', 'KOSDAQ'),
  const StockInfo('247540', '에코프로비엠', 'KOSDAQ'),
  const StockInfo('086520', '에코프로', 'KOSDAQ'),
  const StockInfo('196170', '알테오젠', 'KOSDAQ'),
  const StockInfo('263750', '펄어비스', 'KOSDAQ'),
  const StockInfo('293490', '카카오게임즈', 'KOSDAQ'),
  const StockInfo('095340', 'ISC', 'KOSDAQ'),
  const StockInfo('402030', '코난테크놀로지', 'KOSDAQ'),
  const StockInfo('253590', '네오셈', 'KOSDAQ'),
  const StockInfo('095700', '제넥신', 'KOSDAQ'),
  const StockInfo('096530', '씨젠', 'KOSDAQ'),
  const StockInfo('039030', '이오테크닉스', 'KOSDAQ'),
  const StockInfo('140410', '메지온', 'KOSDAQ'),
  const StockInfo('214150', '클래시스', 'KOSDAQ'),
  const StockInfo('302430', '이노메트리', 'KOSDAQ'),
  const StockInfo('178320', '서진시스템', 'KOSDAQ'),
  const StockInfo('089970', '에이피알', 'KOSDAQ'),
  const StockInfo('073110', '엘엠에스', 'KOSDAQ'),
  const StockInfo('214450', '파마리서치', 'KOSDAQ'),
  const StockInfo('267980', '매일유업', 'KOSDAQ'),
  const StockInfo('228760', '지니뮤직', 'KOSDAQ'),
  const StockInfo('144510', '지씨셀', 'KOSDAQ'),
  const StockInfo('314930', '바이오로그', 'KOSDAQ'),

  // 해외 (NASDAQ)
  const StockInfo('AAPL', 'Apple', 'NASDAQ'),
  const StockInfo('MSFT', 'Microsoft', 'NASDAQ'),
  const StockInfo('GOOGL', 'Alphabet', 'NASDAQ'),
  const StockInfo('AMZN', 'Amazon', 'NASDAQ'),
  const StockInfo('NVDA', 'NVIDIA', 'NASDAQ'),
  const StockInfo('META', 'Meta', 'NASDAQ'),
  const StockInfo('TSLA', 'Tesla', 'NASDAQ'),
  const StockInfo('AMD', 'AMD', 'NASDAQ'),
  const StockInfo('NFLX', 'Netflix', 'NASDAQ'),
  const StockInfo('INTC', 'Intel', 'NASDAQ'),

  // 해외 (NYSE)
  const StockInfo('BRK.B', 'Berkshire Hathaway', 'NYSE'),
  const StockInfo('JPM', 'JPMorgan Chase', 'NYSE'),
  const StockInfo('V', 'Visa', 'NYSE'),
  const StockInfo('JNJ', 'Johnson & Johnson', 'NYSE'),
  const StockInfo('WMT', 'Walmart', 'NYSE'),
  const StockInfo('KO', 'Coca-Cola', 'NYSE'),
  const StockInfo('DIS', 'Disney', 'NYSE'),
  const StockInfo('BA', 'Boeing', 'NYSE'),
];

/// 주식 검색 서비스
List<StockInfo> searchStocks(String query, {String? market}) {
  if (query.isEmpty) return [];

  final q = query.toUpperCase();
  final choQuery = _cho(query);

  var results = stockDb.where((s) {
    if (market != null && s.market != market) return false;
    if (s.code.toUpperCase().contains(q)) return true;
    if (s.name.contains(query)) return true;
    if (_cho(s.name).contains(choQuery)) return true;
    return false;
  }).toList();

  // 정렬: 코드 일치 > 이름 일치 > 초성 일치
  results.sort((a, b) {
    final aCode = a.code.toUpperCase().startsWith(q) ? 0 : 1;
    final bCode = b.code.toUpperCase().startsWith(q) ? 0 : 1;
    if (aCode != bCode) return aCode.compareTo(bCode);
    return a.name.compareTo(b.name);
  });

  return results.take(20).toList();
}

/// 마켓 목록
const markets = ['KOSPI', 'KOSDAQ', 'NASDAQ', 'NYSE'];
