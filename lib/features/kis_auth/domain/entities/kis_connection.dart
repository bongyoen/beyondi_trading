/// KIS Open API 연결 상태.
class KisConnection {
  const KisConnection({
    required this.appKey,
    required this.appSecret,
    this.accessToken,
    this.tokenExpiry,
    this.isPaper = true,
    required this.connectedAt,
  });

  /// 앱키
  final String appKey;

  /// 앱시크릿
  final String appSecret;

  /// 발급된 액세스 토큰
  final String? accessToken;

  /// 토큰 만료 일시
  final DateTime? tokenExpiry;

  /// 모의투자 여부
  final bool isPaper;

  /// 연결 시각
  final DateTime connectedAt;

  /// 토큰이 유효한지 여부
  bool get isTokenValid {
    if (tokenExpiry == null) return false;
    return DateTime.now().isBefore(tokenExpiry!);
  }

  /// 토큰 만료까지 남은 시간 (문자열)
  String get expiryRemaining {
    if (tokenExpiry == null) return '-';
    final remaining = tokenExpiry!.difference(DateTime.now());
    if (remaining.isNegative) return '만료됨';
    if (remaining.inDays > 0) {
      return '${remaining.inDays}일 ${remaining.inHours % 24}시간';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours}시간 ${remaining.inMinutes % 60}분';
    }
    return '${remaining.inMinutes}분';
  }

  /// 앱키 마스킹 (예: PSgy...IWEc)
  String get maskedKey {
    if (appKey.length <= 8) return appKey;
    return '${appKey.substring(0, 4)}...${appKey.substring(appKey.length - 4)}';
  }

  /// 표시용 환경명
  String get envLabel => isPaper ? '모의투자' : '실전투자';
}
