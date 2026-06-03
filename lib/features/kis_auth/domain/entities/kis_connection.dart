class KisCredentials {
  const KisCredentials({
    required this.appKey,
    required this.appSecret,
    this.accountNo,
    this.productCode,
    this.accessToken,
    this.tokenExpiry,
    required this.connectedAt,
  });

  final String appKey;
  final String appSecret;
  final String? accountNo;
  final String? productCode;
  final String? accessToken;
  final DateTime? tokenExpiry;
  final DateTime connectedAt;

  bool get isTokenValid =>
      tokenExpiry != null && DateTime.now().isBefore(tokenExpiry!);

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

  String get maskedKey {
    if (appKey.length <= 8) return appKey;
    return '${appKey.substring(0, 4)}...${appKey.substring(appKey.length - 4)}';
  }
}

class KisConnection {
  const KisConnection({
    this.mock,
    this.real,
    this.useMock = true,
  });

  /// 모의투자 계좌 정보
  final KisCredentials? mock;

  /// 실전투자 계좌 정보
  final KisCredentials? real;

  /// 현재 활성 환경 (true=모의, false=실전)
  final bool useMock;

  KisConnection copyWith({KisCredentials? mock, KisCredentials? real, bool? useMock}) {
    return KisConnection(
      mock: mock ?? this.mock,
      real: real ?? this.real,
      useMock: useMock ?? this.useMock,
    );
  }

  /// 현재 활성 환경의 자격증명
  KisCredentials? get active => useMock ? mock : real;

  bool get isConnected => active != null;
  bool get isTokenValid => active?.isTokenValid ?? false;

  String get envLabel => useMock ? '모의투자' : '실전투자';
  String get expiryRemaining => active?.expiryRemaining ?? '-';
  String get maskedKey => active?.maskedKey ?? '-';
}
