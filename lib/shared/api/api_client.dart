import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_logger.dart';

/// Exception thrown when an API call fails.
///
/// Carries a human-readable [message] and the HTTP [statusCode] when
/// available. This makes failures loud and descriptive (Fail Fast, Fail Loud).
final class ApiException implements Exception {
  /// Creates an [ApiException] with the given [message] and optional [statusCode].
  const ApiException({
    required this.message,
    this.statusCode,
  });

  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code if the exception originated from a server response.
  final int? statusCode;

  @override
  String toString() {
    return statusCode != null
        ? 'ApiException($statusCode): $message'
        : 'ApiException: $message';
  }
}

/// HTTP client for communicating with the Cloudflare Workers API.
///
/// Wraps the `http` package to provide a consistent interface for JSON API
/// calls with structured error handling. Configured at construction with
/// the [baseUrl] and optional [client] (for testing) and [timeout].
///
/// All calls return parsed JSON maps. Non-2xx responses throw [ApiException]
/// with the server's error message when available.
class ApiClient {
  /// Creates an [ApiClient] targeting the given [baseUrl].
  ///
  /// Provide a custom [client] for testing. The [timeout] defaults to 30 seconds.
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _timeout = timeout ?? const Duration(seconds: 30);

  /// Base URL of the API (e.g. "https://api.example.com").
  final String baseUrl;

  final http.Client _client;
  final Duration _timeout;

  /// Sends a GET request to the given [path].
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);

    try {
      final http.Response response = await _client
          .get(uri, headers: _jsonHeaders)
          .timeout(_timeout);
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      await ApiLogger.log(module: 'WORKER', method: 'GET', url: uri.toString(),
          error: e.message);
      throw ApiException(message: 'Network error: ${e.message}');
    } on TimeoutException {
      throw ApiException(message: 'Request timed out. Please try again.');
    }
  }

  /// Sends a POST request to the given [path] with an optional JSON [body].
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: _jsonHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      await ApiLogger.log(module: 'WORKER', method: 'POST', url: uri.toString(),
          error: e.message);
      throw ApiException(message: 'Network error: ${e.message}');
    } on TimeoutException {
      throw ApiException(message: 'Request timed out. Please try again.');
    }
  }

  /// JSON content-type and accept headers for every API request.
  Map<String, String> get _jsonHeaders => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Parses and validates the HTTP response.
  ///
  /// Returns the decoded JSON body on success. Throws [ApiException] with
  /// the server's error message for non-2xx responses.
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Parse the response body at the boundary. Empty bodies become an
    // empty map rather than crashing on decode.
    final Map<String, dynamic> body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    // Log (fire-and-forget, never block response parsing)
    ApiLogger.log(
      module: 'WORKER',
      method: response.request?.method ?? '?',
      url: response.request?.url.toString() ?? '',
      code: response.statusCode,
      summary: response.statusCode >= 200 && response.statusCode < 300 ? 'OK' : null,
      error: response.statusCode >= 200 && response.statusCode < 300 ? null : response.body,
      resBody: response.body.isNotEmpty ? response.body : null,
    );

    // Early Exit: 2xx responses are trusted and returned immediately.
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // Extract a descriptive error message
    final String message = body['error'] as String? ??
        body['message'] as String? ??
        'An unexpected error occurred. Please try again.';

    throw ApiException(message: message, statusCode: response.statusCode);
  }

  /// Closes the underlying HTTP client. Call when the client is no longer needed.
  void dispose() {
    _client.close();
  }
}
