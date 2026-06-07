/// VWAP Cross 적합성 평가 결과
class StockSuitability {
  final String code;
  final String name;
  final String grade; // '적합', '보통', '부적합'
  final double minuteReturn; // 분봉 1년 최고 순손익
  final double minuteWinRate;
  final double dailyWinRate;
  final double ci;
  final String bestConfig; // 최적 설정 라벨

  const StockSuitability({
    required this.code,
    required this.name,
    required this.grade,
    required this.minuteReturn,
    required this.minuteWinRate,
    required this.dailyWinRate,
    required this.ci,
    required this.bestConfig,
  });

  String get returnLabel => minuteReturn >= 0 ? '+${minuteReturn.toStringAsFixed(0)}원' : '${minuteReturn.toStringAsFixed(0)}원';

  bool get isProfitable => minuteReturn > 0;
  bool get isSuitable => grade == '적합' || grade == '보통';

  static final Map<String, StockSuitability> known = {
    '000880': StockSuitability(code:'000880', name:'한화', grade:'적합', minuteReturn:38864, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '001040': StockSuitability(code:'001040', name:'CJ', grade:'적합', minuteReturn:61476, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'기본'),
    '003490': StockSuitability(code:'003490', name:'대한항공', grade:'적합', minuteReturn:9707, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'기본'),
    '005490': StockSuitability(code:'005490', name:'POSCO홀딩스', grade:'적합', minuteReturn:3638, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '009150': StockSuitability(code:'009150', name:'삼성전기', grade:'적합', minuteReturn:10599, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'기본'),
    '010130': StockSuitability(code:'010130', name:'고려아연', grade:'적합', minuteReturn:39619, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'기본'),
    '010140': StockSuitability(code:'010140', name:'삼성중공업', grade:'적합', minuteReturn:14395, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입15'),
    '010620': StockSuitability(code:'010620', name:'현대미포조선', grade:'적합', minuteReturn:8966, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '011200': StockSuitability(code:'011200', name:'HMM', grade:'적합', minuteReturn:7273, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입10'),
    '032580': StockSuitability(code:'032580', name:'델로', grade:'적합', minuteReturn:5779, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입15'),
    '032830': StockSuitability(code:'032830', name:'삼성생명', grade:'적합', minuteReturn:9325, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '034020': StockSuitability(code:'034020', name:'두산에너빌리티', grade:'적합', minuteReturn:450, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '034730': StockSuitability(code:'034730', name:'SK', grade:'적합', minuteReturn:10764, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'기본'),
    '047810': StockSuitability(code:'047810', name:'한국항공우주', grade:'적합', minuteReturn:14593, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입10'),
    '051360': StockSuitability(code:'051360', name:'토비스', grade:'적합', minuteReturn:2934, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입10'),
    '063160': StockSuitability(code:'063160', name:'종근당', grade:'적합', minuteReturn:248, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'기본'),
    '067160': StockSuitability(code:'067160', name:'아프리카TV', grade:'적합', minuteReturn:4549, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '069080': StockSuitability(code:'069080', name:'웹젠', grade:'적합', minuteReturn:15929, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '071050': StockSuitability(code:'071050', name:'한국금융지주', grade:'적합', minuteReturn:5915, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '086790': StockSuitability(code:'086790', name:'하나금융지주', grade:'적합', minuteReturn:22739, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '095340': StockSuitability(code:'095340', name:'ISC', grade:'적합', minuteReturn:41611, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '096770': StockSuitability(code:'096770', name:'SK이노베이션', grade:'적합', minuteReturn:194, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI35-65'),
    '097950': StockSuitability(code:'097950', name:'CJ제일제당', grade:'적합', minuteReturn:8092, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '105560': StockSuitability(code:'105560', name:'KB금융', grade:'적합', minuteReturn:2706, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '112040': StockSuitability(code:'112040', name:'위메이드', grade:'적합', minuteReturn:45047, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI30-70'),
    '115180': StockSuitability(code:'115180', name:'큐리옥스', grade:'적합', minuteReturn:44155, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'TP15/SL10'),
    '128940': StockSuitability(code:'128940', name:'한미약품', grade:'적합', minuteReturn:34564, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입15'),
    '145020': StockSuitability(code:'145020', name:'휴젤', grade:'적합', minuteReturn:42251, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '196170': StockSuitability(code:'196170', name:'알테오젠', grade:'적합', minuteReturn:3883, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입10'),
    '247540': StockSuitability(code:'247540', name:'에코프로비엠', grade:'적합', minuteReturn:12238, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '251270': StockSuitability(code:'251270', name:'넷마블', grade:'적합', minuteReturn:25246, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입20'),
    '256840': StockSuitability(code:'256840', name:'한국파마', grade:'적합', minuteReturn:46459, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입10'),
    '323410': StockSuitability(code:'323410', name:'카카오뱅크', grade:'적합', minuteReturn:54196, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'진입10'),
    '377300': StockSuitability(code:'377300', name:'카카오페이', grade:'적합', minuteReturn:129387, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI30-70'),
    '402340': StockSuitability(code:'402340', name:'SK스퀘어', grade:'적합', minuteReturn:62825, minuteWinRate:0.0, dailyWinRate:0.0, ci:0.0, bestConfig:'RSI30-70'),
  };
}
