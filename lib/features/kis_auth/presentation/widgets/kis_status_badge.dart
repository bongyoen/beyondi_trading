import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../shared/theme/font_helper.dart';
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
              style: inter(
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
                style: inter(
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
    final mockKeyCtl = TextEditingController();
    final mockSecretCtl = TextEditingController();
    final mockAcctCtl = TextEditingController();
    final realKeyCtl = TextEditingController();
    final realSecretCtl = TextEditingController();
    final realAcctCtl = TextEditingController();
    bool showMockSecret = true;
    bool showRealSecret = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('KIS API 연결'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('모의/실전 중 최소 하나는 입력해야 합니다. 둘 다 입력 가능합니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  _envBox('모의계좌', Colors.blue, mockKeyCtl, mockSecretCtl, mockAcctCtl, showMockSecret, (v) => setDialogState(() => showMockSecret = v)),
                  const SizedBox(height: 10),
                  _envBox('실전계좌', Colors.green, realKeyCtl, realSecretCtl, realAcctCtl, showRealSecret, (v) => setDialogState(() => showRealSecret = v)),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              FilledButton(onPressed: () {
                final mk = mockKeyCtl.text.trim();
                final ms = mockSecretCtl.text.trim();
                final rk = realKeyCtl.text.trim();
                final rs = realSecretCtl.text.trim();
                if (mk.isEmpty && ms.isEmpty && rk.isEmpty && rs.isEmpty) return;
                if ((mk.isNotEmpty && ms.isEmpty) || (rk.isNotEmpty && rs.isEmpty)) return;
                final mockAcct = mockAcctCtl.text.trim();
                final realAcct = realAcctCtl.text.trim();
                Navigator.pop(ctx);
                context.read<KisAuthBloc>().add(KisConnectRequested(
                  userId: widget.user.id,
                  mockKey: mk.isNotEmpty ? mk : null,
                  mockSecret: ms.isNotEmpty ? ms : null,
                  mockAccountNo: mockAcct.isNotEmpty ? mockAcct : null,
                  realKey: rk.isNotEmpty ? rk : null,
                  realSecret: rs.isNotEmpty ? rs : null,
                  realAccountNo: realAcct.isNotEmpty ? realAcct : null,
                ));
              }, child: const Text('연결')),
            ],
          );
        },
      ),
    );
  }

  Widget _envBox(String title, Color color,
      TextEditingController keyCtl, TextEditingController secretCtl,
      TextEditingController acctCtl, bool hideSecret, void Function(bool) setHide) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 8),
        TextField(controller: keyCtl, decoration: const InputDecoration(labelText: '앱키', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 6),
        TextField(
          controller: secretCtl,
          decoration: InputDecoration(
            labelText: '앱시크릿', border: const OutlineInputBorder(), isDense: true,
            suffixIcon: IconButton(
              icon: Icon(hideSecret ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
              onPressed: () => setHide(!hideSecret),
            ),
          ),
          obscureText: hideSecret,
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(flex: 3, child: TextField(controller: acctCtl, decoration: const InputDecoration(labelText: '계좌번호 8자리', border: OutlineInputBorder(), isDense: true), maxLength: 8)),
          const SizedBox(width: 6),
          Expanded(child: TextField(decoration: const InputDecoration(labelText: '상품코드', hintText: '01', border: OutlineInputBorder(), isDense: true), maxLength: 2)),
        ]),
      ]),
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentConn = (context.read<KisAuthBloc>().state is KisAuthConnected)
              ? (context.read<KisAuthBloc>().state as KisAuthConnected).connection
              : conn;
          return AlertDialog(
            title: const Text('KIS API 연결 정보'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentConn.mock != null && currentConn.real != null) ...[
                  Row(children: [
                    const Text('환경 전환', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 12),
                    _envChip('모의', Colors.blue, !currentConn.useMock, () {
                      context.read<KisAuthBloc>().add(const KisToggleEnv(true));
                      setDialogState(() {});
                    }),
                    const SizedBox(width: 6),
                    _envChip('실전', Colors.green, currentConn.useMock, () {
                      context.read<KisAuthBloc>().add(const KisToggleEnv(false));
                      setDialogState(() {});
                    }),
                  ]),
                  const SizedBox(height: 8),
                ],
                _infoRow('환경', currentConn.envLabel),
                _infoRow('앱키', currentConn.maskedKey),
                _infoRow('연결 시간', currentConn.active?.connectedAt.toLocal().toString().substring(0, 19) ?? '-'),
                _infoRow('토큰 만료', currentConn.active?.tokenExpiry?.toLocal().toString().substring(0, 19) ?? '-'),
                if (currentConn.active?.accessToken != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const SizedBox(width: 80, child: Text('액세스 토큰', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: currentConn.active!.accessToken!));
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
                                  '${currentConn.active!.accessToken!.substring(0, 20)}...',
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
                _infoRow('남은 시간', currentConn.expiryRemaining),
                _infoRow('상태', currentConn.isTokenValid ? '유효' : '만료'),
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
          );
        },
      ),
    );
  }

  Widget _envChip(String label, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? color : color.withValues(alpha: 0.6),
          ),
        ),
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
