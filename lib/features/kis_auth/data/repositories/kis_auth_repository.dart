import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../backtest/data/datasources/kis_stock_api.dart';
import '../../domain/entities/kis_connection.dart';

/// KIS 연결 정보 저장/조회 추상 계약.
abstract class KisAuthRepository {
  Future<KisConnection> connect({
    required String appKey,
    required String appSecret,
    required String userId,
    bool isPaper = true,
  });

  Future<KisConnection?> getConnection(String userId);

  Future<void> disconnect(String userId);
}

/// Cloudflare Workers API 기반 KIS 인증 저장소.
class WorkersKisAuthRepository implements KisAuthRepository {
  WorkersKisAuthRepository({required this.apiBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<KisConnection> connect({
    required String appKey,
    required String appSecret,
    required String userId,
    bool isPaper = true,
  }) async {
    final kisApi = KisStockApi(
      appKey: appKey,
      appSecret: appSecret,
      isPaper: isPaper,
      client: _client,
    );

    final token = await kisApi.getToken();

    final uri = Uri.parse('$apiBaseUrl/kis/auth');
    final response = await _client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'user_id': userId,
        'app_key': appKey,
        'app_secret': appSecret,
        'access_token': token,
        'token_expiry': kisApi.tokenExpiry?.toIso8601String(),
        'is_paper': isPaper,
      }),
    );

    final saved = _parseSaveResponse(response.body, response.statusCode);

    return KisConnection(
      appKey: appKey,
      appSecret: appSecret,
      accessToken: token,
      tokenExpiry: kisApi.tokenExpiry,
      isPaper: isPaper,
      connectedAt: saved,
    );
  }

  DateTime _parseSaveResponse(String body, int statusCode) {
    if (body.isEmpty) {
      throw KisApiException(
        'KIS 연결 정보 저장 실패: 응답 본문이 비어 있습니다 (HTTP $statusCode).',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw KisApiException(
        'KIS 연결 정보 저장 실패: JSON 파싱 오류 ($e)\nbody=$body',
      );
    }

    if (statusCode != 200) {
      throw KisApiException(
        'KIS 연결 정보 저장 실패 (HTTP $statusCode): '
        '${json['error'] ?? body}',
      );
    }

    final raw = json['connected_at'];
    if (raw is! String || raw.isEmpty) {
      throw KisApiException(
        'KIS 연결 정보 저장 실패: connected_at이 응답에 없습니다.\n'
        'body=$body',
      );
    }

    return DateTime.parse(raw);
  }

  @override
  Future<KisConnection?> getConnection(String userId) async {
    final uri = Uri.parse('$apiBaseUrl/kis/auth?user_id=$userId');
    final response = await _client.get(uri, headers: _jsonHeaders);

    if (response.statusCode != 200 || response.body.isEmpty) return null;

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    if (body['connected'] != true) return null;

    final rawKey = body['app_key'];
    final rawExpiry = body['token_expiry'];
    final rawIsPaper = body['is_paper'];
    final rawConnectedAt = body['connected_at'];

    if (rawKey is! String || rawKey.isEmpty) return null;
    if (rawConnectedAt is! String || rawConnectedAt.isEmpty) return null;

    return KisConnection(
      appKey: rawKey,
      appSecret: body['app_secret'] as String? ?? '',
      accessToken: body['access_token'] as String?,
      tokenExpiry:
          (rawExpiry is String) ? DateTime.tryParse(rawExpiry) : null,
      isPaper: rawIsPaper == true,
      connectedAt: DateTime.parse(rawConnectedAt),
    );
  }

  @override
  Future<void> disconnect(String userId) async {
    final uri = Uri.parse('$apiBaseUrl/kis/auth');
    await _client.delete(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({'user_id': userId}),
    );
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
