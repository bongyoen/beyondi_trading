import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/shared/api/api_logger.dart';
import 'package:beyondi_trading/entities/kis_connection/model/kis_connection.dart';

abstract class KisAuthRepository {
  Future<KisConnection> connect({
    required String userId,
    String? mockKey, String? mockSecret,
    String? mockAccountNo, String? mockProductCode,
    String? realKey, String? realSecret,
    String? realAccountNo, String? realProductCode,
  });

  Future<KisConnection?> getConnection(String userId);
  Future<void> disconnect(String userId, {String? envType});
  Future<void> toggleEnv(String userId, bool useMock);
  Future<KisConnection> refreshToken(String userId);
}

class WorkersKisAuthRepository implements KisAuthRepository {
  WorkersKisAuthRepository({required this.apiBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<KisCredentials?> _connectEnv({
    required String userId,
    required String envType,
    required String appKey,
    required String appSecret,
    String? accountNo,
    String? productCode,
  }) async {
    final kisApi = KisStockApi(appKey: appKey, appSecret: appSecret, isPaper: envType == 'mock');

    final token = await kisApi.getToken();
    final expiry = kisApi.tokenExpiry;
    final now = DateTime.now();
    final normAcct = (accountNo?.isNotEmpty == true) ? accountNo : null;
    final normProd = (productCode?.isNotEmpty == true) ? productCode : null;

    final uri = Uri.parse('$apiBaseUrl/kis/auth');
    final body = {
      'user_id': userId, 'env_type': envType,
      'app_key': appKey, 'app_secret': appSecret,
      'access_token': token, 'token_expiry': expiry?.toIso8601String(),
      'account_no': normAcct, 'product_code': normProd,
    };
    final res = await _client.post(uri, headers: _jsonHeaders, body: jsonEncode(body));
    await ApiLogger.log(module: 'WORKER', method: 'POST', url: '/kis/auth',
        code: res.statusCode, summary: res.statusCode == 200 ? '토큰 저장 완료 ($envType)' : null,
        error: res.statusCode != 200 ? res.body : null);

    // 새 토큰을 kis_token.txt에도 저장 (CLI 동기화)
    try {
      final f = File('${Platform.environment['APPDATA']}\\com.example\\beyondi_trading\\kis_token.txt');
      f.writeAsStringSync(token);
    } catch (_) {}

    return KisCredentials(
      appKey: appKey, appSecret: appSecret,
      accountNo: normAcct, productCode: normProd,
      accessToken: token, tokenExpiry: expiry,
      connectedAt: now,
    );
  }

  @override
  Future<KisConnection> connect({
    required String userId,
    String? mockKey, String? mockSecret,
    String? mockAccountNo, String? mockProductCode,
    String? realKey, String? realSecret,
    String? realAccountNo, String? realProductCode,
  }) async {
    KisCredentials? mock, real;

    if (mockKey != null && mockSecret != null) {
      mock = await _connectEnv(
        userId: userId, envType: 'mock',
        appKey: mockKey, appSecret: mockSecret,
        accountNo: mockAccountNo, productCode: mockProductCode,
      );
    }
    if (realKey != null && realSecret != null) {
      real = await _connectEnv(
        userId: userId, envType: 'real',
        appKey: realKey, appSecret: realSecret,
        accountNo: realAccountNo, productCode: realProductCode,
      );
    }

    return KisConnection(
      mock: mock,
      real: real,
      useMock: real == null && mock != null,
    );
  }

  @override
  Future<KisConnection?> getConnection(String userId) async {
    final uri = Uri.parse('$apiBaseUrl/kis/auth?user_id=$userId');
    final response = await _client.get(uri, headers: _jsonHeaders);
    await ApiLogger.log(module: 'WORKER', method: 'GET', url: '/kis/auth?user_id=$userId',
        code: response.statusCode,
        summary: response.statusCode == 200 && response.body.isNotEmpty ? '연결 정보 조회 성공' : null,
        error: response.statusCode != 200 || response.body.isEmpty ? '연결 정보 없음' : null);
    if (response.statusCode != 200 || response.body.isEmpty) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    KisCredentials? _parse(String key) {
      final d = body[key];
      if (d == null || d is! Map) return null;
      String? nz(String? v) => (v?.isNotEmpty == true) ? v : null;
      return KisCredentials(
        appKey: d['app_key'] as String? ?? '',
        appSecret: d['app_secret'] as String? ?? '',
        accountNo: nz(d['account_no'] as String?),
        productCode: nz(d['product_code'] as String?),
        accessToken: nz(d['access_token'] as String?),
        tokenExpiry: d['token_expiry'] != null ? DateTime.tryParse(d['token_expiry'] as String) : null,
        connectedAt: DateTime.parse(d['connected_at'] as String),
      );
    }

    final mock = _parse('mock');
    final real = _parse('real');
    if (mock == null && real == null) return null;

    return KisConnection(mock: mock, real: real, useMock: real == null && mock != null);
  }

  @override
  Future<void> disconnect(String userId, {String? envType}) async {
    await _client.delete(
      Uri.parse('$apiBaseUrl/kis/auth'),
      headers: _jsonHeaders,
      body: jsonEncode({'user_id': userId, if (envType != null) 'env_type': envType}),
    );
  }

  @override
  Future<void> toggleEnv(String userId, bool useMock) async {
    // localStorage with shared_preferences or keep in memory via BLoC
  }

  @override
  Future<KisConnection> refreshToken(String userId) async {
    await ApiLogger.log(module: 'REFRESH', method: 'START', url: '/token/refresh',
        summary: '갱신 시작 userId=$userId');
    final current = await getConnection(userId);
    if (current == null) {
      throw Exception('연결 정보가 없습니다. 먼저 KIS 연결을 설정하세요.');
    }
    final envType = current.useMock ? 'mock' : 'prod';
    final creds = current.useMock ? current.mock : current.real;
    if (creds == null) throw Exception('${current.envLabel} 자격증명이 없습니다.');
    await ApiLogger.log(module: 'REFRESH', method: 'CONNECTION', url: '/kis/auth',
        summary: 'env=$envType appKey=${creds.appKey.substring(0,8)}... accessToken exists=${creds.accessToken != null} tokenExpiry=${creds.tokenExpiry} connectedAt=${creds.connectedAt}');

    // 항상 KIS API 호출 (setToken 하지 않음 → 캐시 미스 → oauth2/tokenP 호출)
    final kisApi = KisStockApi(
      appKey: creds.appKey,
      appSecret: creds.appSecret,
      isPaper: current.useMock,
    );
    final token = await kisApi.getToken();
    final expiry = kisApi.tokenExpiry;

    await ApiLogger.log(module: 'REFRESH', method: 'KISAPI', url: '/oauth2/tokenP',
        summary: 'token=${token.substring(0, 20)}... expiry=$expiry');

    // Worker 저장
    final uri = Uri.parse('$apiBaseUrl/kis/auth');
    final body = {
      'user_id': userId, 'env_type': envType,
      'app_key': creds.appKey, 'app_secret': creds.appSecret,
      'access_token': token, 'token_expiry': expiry?.toIso8601String(),
      'account_no': creds.accountNo, 'product_code': creds.productCode,
    };
    final res = await _client.post(uri, headers: _jsonHeaders, body: jsonEncode(body));
    await ApiLogger.log(module: 'REFRESH', method: 'POST', url: '/kis/auth',
        code: res.statusCode, summary: 'Worker 저장 결과 HTTP ${res.statusCode}',
        error: res.statusCode != 200 ? res.body.substring(0, 200) : null);

    // kis_token.txt 업데이트
    try {
      final f = File('${Platform.environment['APPDATA']}\\com.example\\beyondi_trading\\kis_token.txt');
      f.writeAsStringSync(token);
      await ApiLogger.log(module: 'REFRESH', method: 'FILE', url: '/kis_token.txt',
          summary: '로컬 파일 저장 완료');
    } catch (_) {}

    final now = DateTime.now();
    final newCreds = KisCredentials(
      appKey: creds.appKey, appSecret: creds.appSecret,
      accountNo: creds.accountNo, productCode: creds.productCode,
      accessToken: token, tokenExpiry: expiry,
      connectedAt: now,
    );
    await ApiLogger.log(module: 'REFRESH', method: 'DONE', url: '/token/refresh',
        summary: '갱신 완료 connectedAt=$now newExpiry=$expiry');
    return current.useMock
        ? current.copyWith(mock: newCreds)
        : current.copyWith(real: newCreds);
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
