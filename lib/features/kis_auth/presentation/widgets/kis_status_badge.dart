import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../entities/user.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../domain/entities/kis_connection.dart';
import '../bloc/kis_auth_bloc.dart';
import '../bloc/kis_auth_event.dart';
import '../bloc/kis_auth_state.dart';

/// 헤더에 표시되는 KIS API 연결 상태 뱃지.
class KisStatusBadge extends StatefulWidget {
  const KisStatusBadge({super.key, required this.user});

  final User user;

  @override
  State<KisStatusBadge> createState() => _KisStatusBadgeState();
}

class _KisStatusBadgeState extends State<KisStatusBadge> {
  @override
  void initState() {
    super.initState();
    context.read<KisAuthBloc>().add(KisStatusRequested(userId: widget.user.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KisAuthBloc, KisAuthState>(
      builder: (context, state) {
        return switch (state) {
          KisAuthInitial() || KisAuthLoading() => _buildBadge(
            context,
            label: '연결 중...',
            color: Colors.grey,
            icon: Icons.sync_rounded,
          ),
          KisAuthConnected(:final connection) => _buildBadge(
            context,
            label: connection.envLabel,
            subtitle: connection.isTokenValid
                ? '만료 ${connection.expiryRemaining}'
                : '토큰 만료',
            color: connection.isTokenValid ? Colors.green : Colors.orange,
            icon: Icons.link_rounded,
            onTap: () => _showConnectionInfo(context, connection),
          ),
          KisAuthDisconnected() => _buildBadge(
            context,
            label: 'KIS 미연결',
            color: Colors.red.shade300,
            icon: Icons.link_off_rounded,
            onTap: () => _showConnectDialog(context),
          ),
          KisAuthFailure(:final message) => Tooltip(
            message: message,
            waitDuration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
            child: _buildBadge(
              context,
              label: '오류',
              color: Colors.red,
              icon: Icons.error_outline_rounded,
              onTap: () => _showErrorDialog(context, message),
            ),
          ),
        };
      },
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: AppConstants.spacingXxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 4),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showConnectDialog(BuildContext context) {
    final appKeyController = TextEditingController();
    final appSecretController = TextEditingController();
    bool hideSecret = true;
    // 설정 파일에서 기존 키 로드 (isPaper 기본값: false=실전)
    bool isPaper = false;
    _loadKisConfig().then((cfg) {
      if (cfg != null) {
        appKeyController.text = cfg.$1;
        appSecretController.text = cfg.$2;
        isPaper = cfg.$3;
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('KIS API 연결'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '한국투자증권 Open API 키를 입력하세요.\n'
                  '설정 파일(%LOCALAPPDATA%\\beyondi_trading\\kis_config.json)에서'
                  ' 자동 로드됩니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: appKeyController,
                  decoration: const InputDecoration(
                    labelText: '앱키 (App Key)',
                    border: OutlineInputBorder(),
                  ),
                  enableInteractiveSelection: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appSecretController,
                  decoration: InputDecoration(
                    labelText: '앱시크릿 (App Secret)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hideSecret
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                      ),
                      tooltip: hideSecret ? '표시' : '숨기기',
                      onPressed: () =>
                          setDialogState(() => hideSecret = !hideSecret),
                    ),
                  ),
                  obscureText: hideSecret,
                  enableInteractiveSelection: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('모의투자'),
                    Switch(
                      value: isPaper,
                      onChanged: (v) => setDialogState(() => isPaper = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final key = appKeyController.text.trim();
                final secret = appSecretController.text.trim();
                if (key.isEmpty || secret.isEmpty) return;
                _saveKisConfig(key, secret, isPaper);
                Navigator.pop(ctx);
                context.read<KisAuthBloc>().add(
                  KisConnectRequested(
                    appKey: key,
                    appSecret: secret,
                    userId: widget.user.id,
                    isPaper: isPaper,
                  ),
                );
              },
              child: const Text('연결'),
            ),
          ],
        ),
      ),
    );
  }

  /// 로컬 설정 파일에서 KIS 키/시크릿 불러오기.
  Future<(String, String, bool)?> _loadKisConfig() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/kis_config.json');
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        (json['app_key'] as String?) ?? '',
        (json['app_secret'] as String?) ?? '',
        (json['is_paper'] as bool?) ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  /// 로컬 설정 파일에 KIS 키/시크릿 저장.
  Future<void> _saveKisConfig(String key, String secret, bool paper) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/kis_config.json');
      await file.writeAsString(jsonEncode({
        'app_key': key,
        'app_secret': secret,
        'is_paper': paper,
      }));
    } catch (_) {}
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('KIS API 연결 오류'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              message,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showConnectDialog(context);
            },
            child: const Text('다시 연결'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showConnectionInfo(BuildContext context, KisConnection conn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('KIS API 연결 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('환경', conn.isPaper ? '모의투자' : '실전투자'),
            _infoRow('앱키', conn.maskedKey),
            _infoRow(
              '연결 시간',
              conn.connectedAt.toLocal().toString().substring(0, 19),
            ),
            _infoRow(
              '토큰 만료',
              conn.tokenExpiry?.toLocal().toString().substring(0, 19) ?? '-',
            ),
            if (conn.accessToken != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const SizedBox(width: 80, child: Text('액세스 토큰', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: conn.accessToken!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('토큰이 클립보드에 복사되었습니다'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Expanded(
                            child: Text(
                              '${conn.accessToken!.substring(0, 20)}...',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 14),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            _infoRow('남은 시간', conn.expiryRemaining),
            _infoRow('상태', conn.isTokenValid ? '유효' : '만료'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<KisAuthBloc>().add(
                KisDisconnectRequested(userId: widget.user.id),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('연결 해제'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
