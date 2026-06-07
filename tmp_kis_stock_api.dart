import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/candle.dart';

/// ?쒓뎅?ъ옄利앷텒 KIS Open API REST ?대씪?댁뼵??
///
/// 紐⑥쓽?ъ옄(vps) ?먮뒗 ?ㅼ쟾?ъ옄(prod) ?섍꼍?먯꽌
/// 援?궡 二쇱떇 ?쇰큺 ?곗씠?곕? 議고쉶?쒕떎.
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

  /// 留덉?留됱쑝濡?諛쒓툒諛쏆? ?좏겙??留뚮즺 ?쇱떆.
  DateTime? get tokenExpiry => _tokenExpiry;

  String? get token => _token;

  /// 湲곗〈??諛쒓툒諛쏆? ?좏겙??吏곸젒 ?ㅼ젙 (濡쒓렇??????λ맂 ?좏겙 ?ъ궗??.
  void setToken(String token, DateTime expiry) {
    _token = token;
    _tokenExpiry = expiry;
  }

  String get _baseUrl => isPaper
      ? 'https://openapivts.koreainvestment.com:29443'
      : 'https://openapi.koreainvestment.com:9443';

  /// ?≪꽭???좏겙??諛쒓툒?섍굅??罹먯떆???좏겙 諛섑솚.
  ///
  /// ?몃??먯꽌???몄텧 媛??(KisAuthRepository?먯꽌 ?ъ슜).
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
        'KIS ?좏겙 諛쒓툒 ?ㅽ뙣: ?묐떟 蹂몃Ц??鍮꾩뼱 ?덉뒿?덈떎.\n'
        'HTTP ${response.statusCode}\n'
        'URL: $_baseUrl/oauth2/tokenP\n\n'
        '?ㅽ듃?뚰겕 ?곌껐 ?먮뒗 SSL ?몄쬆?쒕? ?뺤씤?섏꽭??',
      );
    }

    if (response.statusCode != 200) {
      final errMsg = _parseKisError(response.body);
      throw KisApiException(
        'KIS ?좏겙 諛쒓툒 ?ㅽ뙣 (HTTP ${response.statusCode}): $errMsg',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final rawToken = body['access_token'];
    if (rawToken is! String || rawToken.isEmpty) {
      throw KisApiException(
        'KIS ?좏겙 諛쒓툒 ?ㅽ뙣: ?묐떟??access_token???놁뒿?덈떎. '
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

  /// 援?궡 二쇱떇 ?쇰큺 ?곗씠?곕? 議고쉶?쒕떎.
  ///
  /// [symbol] 醫낅ぉ肄붾뱶 (ex. '005930' ?쇱꽦?꾩옄)
  /// [start] 議고쉶 ?쒖옉??(?ы븿)
  /// [end]   議고쉶 醫낅즺??(?ы븿, 理쒕? 100嫄?
  ///
  /// ??踰??몄텧??理쒕? 100嫄댁쓽 罹붾뱾 ?곗씠??諛섑솚.
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
        '?쇰큺 ?곗씠??議고쉶 ?ㅽ뙣: ${response.statusCode} ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['rt_cd'] != '0') {
      throw KisApiException(
        'API ?ㅻ쪟: [${body['msg_cd']}] ${body['msg1']}',
      );
    }

    final rawList = body['output2'] as List<dynamic>;
    return rawList.map((e) => _parseCandle(e as Map<String, dynamic>)).toList();
  }

  /// 援?궡 二쇱떇 遺꾨큺 ?곗씠?곕? 議고쉶?쒕떎 (?섎（ ?꾩껜).
  ///
  /// [symbol] 醫낅ぉ肄붾뱶 (ex. '005930')
  /// [date]   議고쉶???좎쭨
  ///
  /// **?ㅼ쟾(prod) ?섍꼍?먯꽌留??숈옉**. 紐⑥쓽?ъ옄 誘몄???
  /// 理쒕? 1???꾧퉴吏 議고쉶 媛??
  /// API 1??理쒕? 120嫄???2?쒓컙 ?⑥쐞 4???몄텧濡??섎（ ?꾩껜 ?섏쭛.
  Future<List<Candle>> fetchMinuteCandles({
    required String symbol,
    required DateTime date,
  }) async {
    // 2?쒓컙 媛꾧꺽 4??蹂묐젹 ?몄텧 (09:00~15:30 而ㅻ쾭)
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

  /// 遺꾨큺 1??議고쉶 (理쒕? 120嫄?.
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
      throw KisApiException('遺꾨큺 議고쉶 ?ㅽ뙣: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['rt_cd'] != '0') {
      throw KisApiException('API ?ㅻ쪟: [${body['msg_cd']}] ${body['msg1']}');
    }

    final rawList = body['output2'] as List<dynamic>;
    return rawList
        .map((e) => _parseMinuteCandle(e as Map<String, dynamic>))
        .toList();
  }

  /// KIS ?묐떟 Map ??Candle ?뷀떚??蹂??(?쇰큺).
  Candle _parseCandle(Map<String, dynamic> data) {
    final dateStr = data['stck_bsop_date'];
    if (dateStr is! String || dateStr.length < 8) {
      throw KisApiException('?섎せ??罹붾뱾 ?곗씠?? stck_bsop_date=$dateStr');
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

  /// KIS ?묐떟 Map ??Candle ?뷀떚??蹂??(遺꾨큺).
  Candle _parseMinuteCandle(Map<String, dynamic> data) {
    final dateStr = data['stck_bsop_date'];
    if (dateStr is! String || dateStr.length < 8) {
      throw KisApiException('?섎せ??遺꾨큺 ?곗씠?? stck_bsop_date=$dateStr');
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

  /// KIS API ?ㅻ쪟 ?묐떟?먯꽌 ?щ엺???쎌쓣 ???덈뒗 硫붿떆吏 異붿텧.
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
        'API ?ㅻ쪟: [${body['msg_cd']}] ${body['msg1']}',
      );
    }
  }

  /// 二쇱떇?붽퀬議고쉶 - output1(醫낅ぉ蹂?由ъ뒪??, output2(?⑷퀎)
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
      throw KisApiException('?붽퀬議고쉶 ?ㅽ뙣: ${res.statusCode} ${res.body}');
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

  /// ?ъ옄怨꾩쥖?먯궛?꾪솴議고쉶 - ?ㅼ쟾 only
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
      throw KisApiException('?먯궛?꾪솴議고쉶 ?ㅽ뙣: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);

    final out1 = _safeMap(body['output1']);
    final out2 = _safeListMap(body['output2']);
    return (out1, out2);
  }

  /// 留ㅼ닔媛?μ“??  Future<Map<String, dynamic>> fetchBuyPower({
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
      throw KisApiException('留ㅼ닔媛?μ“???ㅽ뙣: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);
    return (body['output'] as Map<String, dynamic>?) ?? {};
  }

  /// 湲곌컙蹂꾨ℓ留ㅼ넀?듯쁽?⑹“??- ?ㅼ쟾 only
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
      throw KisApiException('湲곌컙?먯씡議고쉶 ?ㅽ뙣: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _checkResponse(body);

    final out1 = _safeMap(body['output1']);
    final out2 = _safeListMap(body['output2']);
    return (out1, out2);
  }

  void dispose() => _client.close();
}

/// KIS API ?몄텧 ?ㅽ뙣 ??諛쒖깮?섎뒗 ?덉쇅.
class KisApiException implements Exception {
  KisApiException(this.message);
  final String message;
  @override
  String toString() => 'KisApiException: $message';
}
