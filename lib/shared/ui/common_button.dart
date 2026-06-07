import 'package:flutter/material.dart';

enum CommonButtonStyle { filled, outlined, text }

class CommonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final CommonButtonStyle style;
  final VoidCallback? onPressed;
  final Color? color;
  final double? height;

  const CommonButton({
    super.key,
    required this.label,
    this.icon,
    this.style = CommonButtonStyle.filled,
    this.onPressed,
    this.color,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    final disabled = onPressed == null;

    switch (style) {
      case CommonButtonStyle.outlined:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label, style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: disabled ? null : effectiveColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size(0, height ?? 36),
          ),
        );
      case CommonButtonStyle.text:
        return TextButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label, style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
            foregroundColor: disabled ? null : effectiveColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size(0, height ?? 36),
          ),
        );
      default:
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label, style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size(0, height ?? 36),
          ),
        );
    }
  }
}

class CommonIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onPressed;

  const CommonIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.size = 16,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size,
        icon: Icon(icon, color: onPressed == null ? Colors.grey : color),
        onPressed: onPressed,
      ),
    );
  }
}
