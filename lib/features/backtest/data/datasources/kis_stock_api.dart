import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/candle.dart';

/// 한국투자증권 KIS Open API REST 클라이언트.
///
/// 모의투자(vps) 또는 실전투자(prod) 환경에서
/// 국내 주식 일봉 데이터를 조회한다.
class KisStockApi {
  KisStockApi({
    required this.appKey,
    required this.appSecret,
    this.isPaper = true,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String appKey;
  final String appSecret;
  final bool isPaper;
  final http.Client _client;

  String? _token;
  DateTime? _tokenExpiry;

  /// 마지막으로 발급받은 토큰의 만료 일시.
  DateTime? get tokenExpiry => _tokenExpiry;

  String get _baseUrl => isPaper
      ? 'https://openapivts.koreainvestment.com:29443'
      : 'https://openapi.koreainvestment.com:9443';

  /// 액세스 토큰을 발급하거나 캐시된 토큰 반환.
  ///
  /// 외부에서도 호출 가능 (KisAuthRepository에서 사용).
  Future<String> getToken() async {
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _token!;
    }

    final uri = Uri.parse('$_baseUrl/oauth2/tokenP');
    final response = await _client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'grant_type': 'client_credentials',
        'appkey': appKey,
        'appsecret': appSecret,
      }),
    );

    if (response.body.isEmpty) {
      throw KisApiException(
        'KIS 토큰 발급 실패: 응답 본문이 비어 있습니다.\n'
        'HTTP ${response.statusCode}\n'
        'URL: $_baseUrl/oauth2/tokenP\n\n'
        '네트워크 연결 또는 SSL 인증서를 확인하세요.',
      );
    }

    if (response.statusCode != 200) {
      final errMsg = _parseKisError(response.body);
      throw KisApiException(
        'KIS 토큰 발급 실패 (HTTP ${response.statusCode}): $errMsg',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final rawToken = body['access_token'];
    if (rawToken is! String || rawToken.isEmpty) {
      throw KisApiException(
        'KIS 토큰 발급 실패: 응답에 access_token이 없습니다. '
        'body=${response.body}',
      );
    }
    _token = rawToken;

    final rawExpired = body['access_token_token_expired'];
    _tokenExpiry = (rawExpired is String && rawExpired.isNotEmpty)
        ? DateTime.tryParse(rawExpired)
        : null;

    return _token!;
  }

  /// 국내 주식 일봉 데이터를 조회한다.
  ///
  /// [symbol] 종목코드 (ex. '005930' 삼성전자)
  /// [start] 조회 시작일 (포함)
  /// [end]   조회 종료일 (포함, 최대 100건)
  ///
  /// 한 번 호출에 최대 100건의 캔들 데이터 반환.
  Future<List<Candle>> fetchDailyCandles({
    required String symbol,
    required DateTime start,
    required DateTime end,
  }) async {
    final token = await getToken();

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice',
    ).replace(queryParameters: {
      'FID_COND_MRKT_DIV_CODE': 'J',
      'FID_INPUT_ISCD': symbol,
      'FID_INPUT_DATE_1': _formatDate(start),
      'FID_INPUT_DATE_2': _formatDate(end),
      'FID_PERIOD_DIV_CODE': 'D',
      'FID_ORG_ADJ_PRC': '0',
    });

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $token',
        'appkey': appKey,
        'appsecret': appSecret,
        'custtype': 'P',
        'tr_id': 'FHKST03010100',
      },
    );

    if (response.statusCode != 200) {
      throw KisApiException(
        '일봉 데이터 조회 실패: ${response.statusCode} ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['rt_cd'] != '0') {
      throw KisApiException(
        'API 오류: [${body['msg_cd']}] ${body['msg1']}',
      );
    }

    final rawList = body['output2'] as List<dynamic>;
    return rawList.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
  }

  /// 국내 주식 분봉 데이터를 조회한다 (하루 전체).
  ///
  /// [symbol] 종목코드 (ex. '005930')
  /// [date]   조회할 날짜
  ///
  /// **실전(prod) 환경에서만 동작**. 모의투자 미지원.
  /// 최대 1년 전까지 조회 가능.
  /// API 1회 최대 120건 → 2시간 단위 4회 호출로 하루 전체 수집.
  Future<List<Candle>> fetchMinuteCandles({
    required String symbol,
    required DateTime date,
  }) async {
    final all = <Candle>[];
    // 2시간 간격으로 4회 호출 (09:00~15:30 커버)
    for (final startTime in ['153000', '133000', '113000', '093000']) {
      final chunk = await _fetchMinuteChunk(symbol: symbol, date: date, startTime: startTime);
      for (final c in chunk) {
        if (!all.any((e) => e.timestamp == c.timestamp)) all.add(c);
      }
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  /// 분봉 1회 조회 (최대 120건).
  Future<List<Candle>> _fetchMinuteChunk({
    required String symbol,
    required DateTime date,
    required String startTime,
    bool includePast = false,
  }) async {
    final token = await getToken();

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/quotations/inquire-time-dailychartprice',
    ).replace(queryParameters: {
      'FID_COND_MRKT_DIV_CODE': 'J',
      'FID_INPUT_ISCD': symbol,
      'FID_INPUT_HOUR_1': startTime,
      'FID_INPUT_DATE_1': _formatDate(date),
      'FID_PW_DATA_INCU_YN': includePast ? 'Y' : 'N',
      'FID_FAKE_TICK_INCU_YN': '',
    });

    final response = await _client.get(uri, headers: {
      'Content-Type': 'application/json',
      'authorization': 'Bearer $token',
      'appkey': appKey,
      'appsecret': appSecret,
      'custtype': 'P',
      'tr_id': 'FHKST03010230',
    });

    if (response.statusCode != 200) {
      throw KisApiException('분봉 조회 실패: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['rt_cd'] != '0') {
      throw KisApiException('API 오류: [${body['msg_cd']}] ${body['msg1']}');
    }

    final rawList = body['output2'] as List<dynamic>;
    return rawList
        .map((e) => _parseMinuteCandle(e as Map<String, dynamic>))
        .toList();
  }

  /// KIS 응답 Map → Candle 엔티티 변환 (일봉).
  Candle _parseCandle(Map<String, dynamic> data) {
    final dateStr = data['stck_bsop_date'];
    if (dateStr is! String || dateStr.length < 8) {
      throw KisApiException('잘못된 캔들 데이터: stck_bsop_date=$dateStr');
    }

    return Candle(
      timestamp: DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
      ),
      open: _parseDouble(data['stck_oprc']),
      high: _parseDouble(data['stck_hgpr']),
      low: _parseDouble(data['stck_lwpr']),
      close: _parseDouble(data['stck_clpr']),
      volume: _parseDouble(data['acml_vol']),
    );
  }

  /// KIS 응답 Map → Candle 엔티티 변환 (분봉).
  Candle _parseMinuteCandle(Map<String, dynamic> data) {
    final dateStr = data['stck_bsop_date'];
    if (dateStr is! String || dateStr.length < 8) {
      throw KisApiException('잘못된 분봉 데이터: stck_bsop_date=$dateStr');
    }

    final timeStr = data['stck_cntg_hour'] as String? ?? '000000';

    return Candle(
      timestamp: DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
        int.parse(timeStr.substring(0, 2)),
        int.parse(timeStr.substring(2, 4)),
        int.parse(timeStr.substring(4, 6)),
      ),
      open: _parseDouble(data['stck_oprc']),
      high: _parseDouble(data['stck_hgpr']),
      low: _parseDouble(data['stck_lwpr']),
      close: _parseDouble(data['stck_prpr']),
      volume: _parseDouble(data['cntg_vol']),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatDate(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'text/plain',
    'charset': 'UTF-8',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  /// KIS API 오류 응답에서 사람이 읽을 수 있는 메시지 추출.
  String _parseKisError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['message'] as String?) ??
          (json['error'] as String?) ??
          (json['msg1'] as String?) ??
          body;
    } catch (_) {
      return body;
    }
  }

  void dispose() => _client.close();
}

/// KIS API 호출 실패 시 발생하는 예외.
class KisApiException implements Exception {
  KisApiException(this.message);
  final String message;
  @override
  String toString() => 'KisApiException: $message';
}
