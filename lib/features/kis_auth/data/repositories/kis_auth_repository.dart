import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../backtest/data/datasources/kis_stock_api.dart';
import '../../domain/entities/kis_connection.dart';

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
    await _client.post(uri, headers: _jsonHeaders, body: jsonEncode({
      'user_id': userId, 'env_type': envType,
      'app_key': appKey, 'app_secret': appSecret,
      'access_token': token, 'token_expiry': expiry?.toIso8601String(),
      'account_no': normAcct, 'product_code': normProd,
    }));

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

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
