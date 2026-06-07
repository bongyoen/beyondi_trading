import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';
import 'package:beyondi_trading/entities/user/model/user.dart';
import 'package:beyondi_trading/shared/constants/app_constants.dart';
import 'package:beyondi_trading/entities/kis_connection/model/kis_connection.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_event.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_state.dart';

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
          KisAuthConnected(:final connection) => Padding(
            padding: EdgeInsets.zero,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _miniBadge(
                label: '모의',
                connected: connection.mock != null && connection.mock!.isTokenValid,
                onTap: () => _showConnectionInfo(context, connection),
              ),
              const SizedBox(width: 4),
              _miniBadge(
                label: '실전',
                connected: connection.real != null && connection.real!.isTokenValid,
                onTap: () => _showConnectionInfo(context, connection),
              ),
            ]),
          ),
          KisAuthDisconnected() => Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => _showEnvConnectDialog(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: 10, color: Colors.blue),
                  const SizedBox(width: 3),
                  Text('모의연결', style: inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue)),
                ]),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showEnvConnectDialog(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: 10, color: Colors.green),
                  const SizedBox(width: 3),
                  Text('실전연결', style: inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green)),
                ]),
              ),
            ),
          ]),
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

  Widget _miniBadge({
    required String label,
    required bool connected,
    required VoidCallback onTap,
  }) {
    final color = connected ? Colors.green : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(connected ? Icons.link_rounded : Icons.link_off_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
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

  void _showEnvConnectDialog(BuildContext context, bool isMock) {
    final keyCtl = TextEditingController();
    final secretCtl = TextEditingController();
    final acctCtl = TextEditingController();
    bool hideSecret = true;
    final title = isMock ? '모의계좌 연결' : '실전계좌 연결';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: keyCtl,
                    decoration: const InputDecoration(labelText: '앱키', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: secretCtl,
                    decoration: InputDecoration(
                      labelText: '앱시크릿', border: const OutlineInputBorder(), isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(hideSecret ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                        onPressed: () => setDialogState(() => hideSecret = !hideSecret),
                      ),
                    ),
                    obscureText: hideSecret,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: acctCtl,
                        decoration: const InputDecoration(labelText: '계좌번호 8자리', border: OutlineInputBorder(), isDense: true),
                        maxLength: 8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: '상품코드', hintText: '01', border: OutlineInputBorder(), isDense: true),
                        maxLength: 2,
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              FilledButton(onPressed: () {
                final key = keyCtl.text.trim();
                final secret = secretCtl.text.trim();
                if (key.isEmpty || secret.isEmpty) return;
                final acct = acctCtl.text.trim();
                Navigator.pop(ctx);
                context.read<KisAuthBloc>().add(KisConnectRequested(
                  userId: widget.user.id,
                  mockKey: isMock ? key : null,
                  mockSecret: isMock ? secret : null,
                  mockAccountNo: isMock && acct.isNotEmpty ? acct : null,
                  realKey: !isMock ? key : null,
                  realSecret: !isMock ? secret : null,
                  realAccountNo: !isMock && acct.isNotEmpty ? acct : null,
                ));
              }, child: const Text('연결')),
            ],
          );
        },
      ),
    );
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
              _showEnvConnectDialog(context, true);
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
          return AlertDialog(
            title: const Text('KIS API 연결 정보'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _envInfoSection(ctx, '모의투자', Colors.blue, conn.mock, true, conn, setDialogState),
                    const SizedBox(height: 12),
                    _envInfoSection(ctx, '실전투자', Colors.green, conn.real, false, conn, setDialogState),
                  ],
                ),
              ),
            ),
            actions: [
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

  Widget _envInfoSection(BuildContext dialogCtx, String title, Color color,
      KisCredentials? creds, bool isMock, KisConnection conn, void Function(void Function()) setState) {
    final connected = creds != null && creds.isTokenValid;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: connected ? 0.5 : 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(connected ? Icons.link_rounded : Icons.link_off_rounded, size: 14, color: connected ? color : Colors.grey),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: connected ? color : Colors.grey)),
          const Spacer(),
          Text(connected ? '연결됨' : '미연결', style: TextStyle(fontSize: 11, color: connected ? Colors.green : Colors.grey)),
        ]),
        if (connected) ...[
          const SizedBox(height: 8),
          _infoRow('앱키', creds.maskedKey),
          _infoRow('연결 시간', creds.connectedAt.toLocal().toString().substring(0, 19)),
          _infoRow('토큰 만료', creds.tokenExpiry?.toLocal().toString().substring(0, 19) ?? '-'),
          _infoRow('남은 시간', creds.expiryRemaining),
          if (creds.accessToken != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const SizedBox(width: 80, child: Text('액세스 토큰', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: creds.accessToken!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('토큰이 클립보드에 복사되었습니다'), duration: Duration(seconds: 2)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Expanded(child: Text('${creds.accessToken!.substring(0, 20)}...', style: const TextStyle(fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<KisAuthBloc>().add(KisDisconnectRequested(
                userId: widget.user.id,
              ));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
            child: const Text('연결 해제', style: TextStyle(fontSize: 11)),
          ),
        ] else ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showEnvConnectDialog(context, isMock);
            },
            style: OutlinedButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
            child: Text('${title} 연결', style: TextStyle(fontSize: 11)),
          ),
        ],
      ]),
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
