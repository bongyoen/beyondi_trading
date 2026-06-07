import 'dart:convert';
import 'dart:io';

/// API 호출 로깅 유틸리티.
///
/// - 로그 파일: `%APPDATA%/com.example/beyondi_trading/api_log.txt`
/// - 응답 본문은 최대 200자
/// - 실패 시 상세 기록, 성공 시 간략 기록
class ApiLogger {
  static const _maxLen = 200;

  static Future<File> _file() async {
    final dir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
    final d = Directory(dir);
    if (!d.existsSync()) d.createSync(recursive: true);
    return File('$dir\\api_log.log');
  }

  static String _truncate(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.length <= _maxLen ? s : '${s.substring(0, _maxLen)}...';
  }

  /// API 호출 로그를 파일에 기록.
  ///
  /// [module] 호출 모듈명 (KIS, WORKER, SCREEN)
  /// [method] HTTP 메서드 (GET, POST)
  /// [url] 요청 URL
  /// [code] HTTP 응답 코드
  /// [summary] 성공 시 간략 요약 (예: "50개 종목")
  /// [error] 실패 시 오류 메시지 (200자 제한)
  /// [reqBody] 요청 본문 (200자 제한)
  /// [resBody] 응답 본문 (200자 제한)
  static Future<void> log({
    required String module,
    required String method,
    required String url,
    int? code,
    String? summary,
    String? error,
    dynamic reqBody,
    dynamic resBody,
  }) async {
    try {
      final now = DateTime.now().toString().substring(0, 19);
      final rb = reqBody is String ? reqBody : (reqBody != null ? jsonEncode(reqBody) : null);
      final rs = resBody is String ? resBody : (resBody != null ? jsonEncode(resBody) : null);
      final status = code != null ? ' → $code' : '';
      final ok = code != null && code >= 200 && code < 300;

      String line;
      if (ok) {
        line = '[${now}] [${module}] ${method} ${url}${status} ${summary ?? ""}\n';
      } else {
        line = '[${now}] [${module}] ${method} ${url}${status}';
        if (error != null) line += ' ERROR: ${_truncate(error)}';
        if (rb != null && rb.isNotEmpty) line += ' REQ: ${_truncate(rb)}';
        if (rs != null && rs.isNotEmpty) line += ' RES: ${_truncate(rs)}';
        line += '\n';
      }

      final f = await _file();
      await f.writeAsString(line, mode: FileMode.append);
      stdout.write(line);
    } catch (_) {
      // 로깅 실패는 무시
    }
  }
}
