import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_logger.dart';
import 'package:beyondi_trading/entities/candle/model/candle.dart';

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

  String? get token => _token;

  /// 기존에 발급받은 토큰을 직접 설정 (로그인 시 저장된 토큰 재사용).
  void setToken(String token, DateTime expiry) {
    _token = token;
    _tokenExpiry = expiry;
  }

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
      await ApiLogger.log(module: 'TOKEN', method: 'CACHE', url: '/oauth2/tokenP',
          summary: '캐시 사용: 만료까지 ${_tokenExpiry!.difference(DateTime.now()).inMinutes}분');
      return _token!;
    }

    await ApiLogger.log(module: 'TOKEN', method: 'CALL', url: '/oauth2/tokenP',
        summary: 'KIS API 직접 호출 appKey=${appKey.substring(0,8)}... isPaper=$isPaper');

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

    await ApiLogger.log(module: 'TOKEN', method: 'SUCCESS', url: '/oauth2/tokenP',
        summary: '토큰=$_token expiry=$_tokenExpiry');
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
    // 2시간 간격 4회 병렬 호출 (09:00~15:30 커버)
    final chunks = await Future.wait(
      ['153000', '133000', '113000', '093000'].map((t) =>
        _fetchMinuteChunk(symbol: symbol, date: date, startTime: t)),
    );
    final seen = <DateTime>{};
    final all = <Candle>[];
    for (final chunk in chunks) {
      for (final c in chunk) {
        if (seen.add(c.timestamp)) all.add(c);
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
    bool includePast = true,
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
      'FID_FAKE_TICK_INCU_YN': 'N',
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

  Map<String, String> _authHeaders(String token, String trId) => {
    'Content-Type': 'application/json',
    'authorization': 'Bearer $token',
    'appkey': appKey,
    'appsecret': appSecret,
    'custtype': 'P',
    'tr_id': trId,
  };

  void _checkResponse(Map<String, dynamic> body) {
    if (body['rt_cd'] != '0') {
      throw KisApiException(
        'API 오류: [${body['msg_cd']}] ${body['msg1']}',
      );
    }
  }

  /// 주식잔고조회 - output1(종목별 리스트), output2(합계)
  Future<(List<Map<String, dynamic>>, Map<String, dynamic>)> fetchBalance({
    required String accountNo,
    required String productCode,
  }) async {
    final token = await getToken();
    final trId = isPaper ? 'VTTC8434R' : 'TTTC8434R';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/trading/inquire-balance',
    ).replace(queryParameters: {
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'AFHR_FLPR_YN': 'N',
      'OFL_YN': '',
      'INQU_DVSN': '01',
      'UNPR_DVSN': '01',
      'FUND_STLD_YN': 'N',
      'FNCG_AMT_AUTO_REDCMS_YN': 'N',
      'PRCS_DVSN': '01',
      'COST_ICL_YN': 'N',
      'CTX_AREA_FK100': '',
      'CTX_AREA_NK100': '',
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) {
      throw KisApiException('잔고조회 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);

    final out1 = _safeListMap(body['output1']);
    final out2 = _safeMap(body['output2']);
    return (out1, out2);
  }

  static Map<String, dynamic> _safeMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is List && v.isNotEmpty) {
      final e = v[0];
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return Map<String, dynamic>.from(e);
    }
    return {};
  }

  static List<Map<String, dynamic>> _safeListMap(dynamic v) {
    if (v is List<Map<String, dynamic>>) return v;
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (v is Map) return [Map<String, dynamic>.from(v)];
    return [];
  }

  /// 투자계좌자산현황조회 - 실전 only
  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> fetchAccountAssetSummary({
    required String accountNo,
    required String productCode,
  }) async {
    final token = await getToken();
    const trId = 'CTRP6548R';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/trading/inquire-account-balance',
    ).replace(queryParameters: {
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'INQR_DVSN': '01',
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) {
      throw KisApiException('자산현황조회 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);

    final out1 = _safeMap(body['output1']);
    final out2 = _safeListMap(body['output2']);
    return (out1, out2);
  }

  /// 매수가능조회
  Future<Map<String, dynamic>> fetchBuyPower({
    required String accountNo,
    required String productCode,
    String symbol = '',
  }) async {
    final token = await getToken();
    final trId = isPaper ? 'VTTC8908R' : 'TTTC8908R';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/trading/inquire-psbl-order',
    ).replace(queryParameters: {
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'PDNO': '',
      'ORD_DVSN': '00',
      'ORD_QTY': '0',
      'ORD_UNPR': '0',
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) {
      throw KisApiException('매수가능조회 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);
    return (body['output'] as Map<String, dynamic>?) ?? {};
  }

  /// 기간별매매손익현황조회 - 실전 only
  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> fetchPeriodTradeProfit({
    required String accountNo,
    required String productCode,
    required String startDate,
    required String endDate,
  }) async {
    final token = await getToken();
    const trId = 'TTTC8715R';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/trading/inquire-period-trade-profit',
    ).replace(queryParameters: {
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'SORT_DVSN': '02',
      'INQR_STRT_DT': startDate,
      'INQR_END_DT': endDate,
      'CBLC_DVSN': '00',
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) {
      throw KisApiException('기간손익조회 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);

    final out1 = _safeMap(body['output1']);
    final out2 = _safeListMap(body['output2']);
    return (out1, out2);
  }

  /// 매수 주문
  Future<Map<String, dynamic>> orderBuy({
    required String accountNo,
    required String productCode,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  }) async {
    final token = await getToken();
    final trId = isPaper ? 'VTTC0802U' : 'TTTC0802U';

    final uri = Uri.parse('$_baseUrl/uapi/domestic-stock/v1/trading/order-cash');
    final body = jsonEncode({
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'PDNO': symbol,
      'ORD_DVSN': orderDivision,
      'ORD_QTY': quantity.toString(),
      'ORD_UNPR': price.toStringAsFixed(0),
    });

    final res = await _client.post(uri, headers: _authHeaders(token, trId), body: body);
    if (res.statusCode != 200) {
      throw KisApiException('매수주문 실패: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(json);
    return json;
  }

  /// 매도 주문
  Future<Map<String, dynamic>> orderSell({
    required String accountNo,
    required String productCode,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  }) async {
    final token = await getToken();
    final trId = isPaper ? 'VTTC0801U' : 'TTTC0801U';

    final uri = Uri.parse('$_baseUrl/uapi/domestic-stock/v1/trading/order-cash');
    final body = jsonEncode({
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'PDNO': symbol,
      'ORD_DVSN': orderDivision,
      'ORD_QTY': quantity.toString(),
      'ORD_UNPR': price.toStringAsFixed(0),
    });

    final res = await _client.post(uri, headers: _authHeaders(token, trId), body: body);
    if (res.statusCode != 200) {
      throw KisApiException('매도주문 실패: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(json);
    return json;
  }

  /// 주문 취소
  Future<Map<String, dynamic>> cancelOrder({
    required String accountNo,
    required String productCode,
    required String orgOrderNo,
    required String symbol,
    required int quantity,
    required double price,
    String orderDivision = '00',
  }) async {
    final token = await getToken();
    final trId = isPaper ? 'VTTC0803U' : 'TTTC0803U';

    final uri = Uri.parse('$_baseUrl/uapi/domestic-stock/v1/trading/order-rvsecncl');
    final body = jsonEncode({
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'KRX_FWDG_ORD_ORGNO': '',
      'ORGN_ODNO': orgOrderNo,
      'ORD_DVSN': orderDivision,
      'RVSE_CNCL_DVSN_CD': '02',
      'ORD_QTY': quantity.toString(),
      'ORD_UNPR': price.toStringAsFixed(0),
    });

    final res = await _client.post(uri, headers: _authHeaders(token, trId), body: body);
    if (res.statusCode != 200) {
      throw KisApiException('주문취소 실패: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(json);
    return json;
  }

  /// 일별 주문 내역 조회
  Future<List<Map<String, dynamic>>> fetchDailyOrderDetail({
    required String accountNo,
    required String productCode,
    required String startDate,
    required String endDate,
  }) async {
    final token = await getToken();
    final trId = isPaper ? 'VTTC8001R' : 'TTTC8001R';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/trading/inquire-daily-ccld',
    ).replace(queryParameters: {
      'CANO': accountNo,
      'ACNT_PRDT_CD': productCode,
      'INQR_STRT_DT': startDate,
      'INQR_END_DT': endDate,
      'SLL_BUY_DVSN': '00',
      'CCLD_NCCS_DVSN': '00',
      'OVRS_EXCG_YN': 'N',
      'PRCS_DVSN': '00',
      'CTX_AREA_FK100': '',
      'CTX_AREA_NK100': '',
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) {
      throw KisApiException('주문내역조회 실패: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(json);
    return _safeListMap(json['output1']);
  }

  /// 휴일 여부 확인
  Future<bool> checkHoliday(String date) async {
    final token = await getToken();
    const trId = 'CTPF1702R';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/quotations/inquire-holiday-yn',
    ).replace(queryParameters: {
      'BASS_DT': date,
      'CTX_AREA_NK': '',
      'CTX_AREA_FK': '',
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['rt_cd'] != '0') return false;
    final output = body['output'] as Map<String, dynamic>?;
    if (output == null) return false;
    return output['bass_dt_yn'] == 'Y';
  }

  /// 등락률 순위 조회
  Future<List<Map<String, dynamic>>> fetchFluctuationRank({
    required String divCode,
    required int count,
  }) async {
    final token = await getToken();
    const trId = 'FHPST01700000';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/ranking/fluctuation',
    ).replace(queryParameters: {
      'fid_rsfl_rate2': '',
      'fid_cond_mrkt_div_code': 'J',
      'fid_cond_scr_div_code': '20170',
      'fid_input_iscd': '0000',
      'fid_rank_sort_cls_code': '0',
      'fid_input_cnt_1': count.toString(),
      'fid_prc_cls_code': '0',
      'fid_input_price_1': '0',
      'fid_input_price_2': '1000000',
      'fid_vol_cnt': '100000',
      'fid_trgt_cls_code': '0',
      'fid_trgt_exls_cls_code': '0',
      'fid_div_cls_code': '0',
      'fid_rsfl_rate1': '0',
    });

    await ApiLogger.log(module: 'RANK', method: 'START', url: uri.toString(),
        summary: 'baseUrl=$_baseUrl isPaper=$isPaper trId=$trId token=${token.length > 15 ? token.substring(0, 15) : token}...');

    final res = await _client.get(uri, headers: _authHeaders(token, trId));

    await ApiLogger.log(module: 'RANK', method: 'RESPONSE', url: '/ranking/fluctuation',
        code: res.statusCode,
        summary: 'HTTP ${res.statusCode} bodyLength=${res.body.length}',
        resBody: res.body.length > 200 ? res.body.substring(0, 200) : res.body);

    if (res.statusCode != 200) {
      throw KisApiException('등락률순위 조회 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    await ApiLogger.log(module: 'RANK', method: 'PARSE', url: '/ranking/fluctuation',
        summary: 'rt_cd=${body['rt_cd']} msg_cd=${body['msg_cd']} msg1=${body['msg1']} output 건수=${(body['output'] as List?)?.length}');
    _checkResponse(body);
    return _safeListMap(body['output']);
  }

  /// 주식 현재가 조회
  Future<Map<String, dynamic>> inquirePrice(String symbol) async {
    final token = await getToken();
    const trId = 'FHKST01010100';

    final uri = Uri.parse(
      '$_baseUrl/uapi/domestic-stock/v1/quotations/inquire-price',
    ).replace(queryParameters: {
      'FID_COND_MRKT_DIV_CODE': 'J',
      'FID_INPUT_ISCD': symbol,
    });

    final res = await _client.get(uri, headers: _authHeaders(token, trId));
    if (res.statusCode != 200) {
      throw KisApiException('현재가 조회 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);
    return _safeMap(body['output']);
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
