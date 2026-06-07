import 'package:flutter/material.dart';
import '../theme/font_helper.dart';

/// 공통 카드 위젯. 기본 단위 UI (Atomic).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.cs,
    this.title,
    this.icon,
    this.children = const [],
  });

  final ColorScheme cs;
  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Icon(icon ?? Icons.analytics_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(title!, style: poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
        ],
        ...children,
      ]),
    );
  }
}
