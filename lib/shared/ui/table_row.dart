import 'package:flutter/material.dart';

/// 공통 테이블 헤더 셀. flex 비율로 너비 조절.
class Th extends StatelessWidget {
  const Th(this.label, this.cs, {super.key, this.flex = 1});

  final String label;
  final ColorScheme cs;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ),
    );
  }
}

/// 공통 테이블 데이터 셀. flex 비율로 너비 조절.
class Td extends StatelessWidget {
  const Td(this.text, {super.key, this.flex = 1, this.color, this.bold = false});

  final String text;
  final int flex;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Text(text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: color,
            ),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// 고정폭 테이블 헤더 셀 (sized, flex 아님).
class ThFixed extends StatelessWidget {
  const ThFixed(this.label, this.cs, {super.key, this.width = 100});

  final String label;
  final ColorScheme cs;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ),
    );
  }
}

/// 고정폭 테이블 데이터 셀 (sized, flex 아님).
class TdFixed extends StatelessWidget {
  const TdFixed(this.text, {super.key, this.width = 100, this.color, this.bold = false});

  final String text;
  final double width;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color)),
      ),
    );
  }
}
