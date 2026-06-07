import 'package:flutter/material.dart';

class DropdownItem<T> {
  final T value;
  final String label;
  const DropdownItem(this.label, this.value);
}

class CommonDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T>? onChanged;
  final bool isDense;

  const CommonDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.isDense = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isDense ? 4 : 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: isDense,
          style: TextStyle(fontSize: isDense ? 12 : 14, color: cs.onSurface),
          dropdownColor: cs.surfaceContainerHighest,
          items: items.map((item) => DropdownMenuItem(
            value: item.value,
            child: Text(item.label, style: TextStyle(fontSize: isDense ? 12 : 14, color: cs.onSurface)),
          )).toList(),
          onChanged: (v) {
            if (v != null && onChanged != null) onChanged!(v);
          },
        ),
      ),
    );
  }
}
