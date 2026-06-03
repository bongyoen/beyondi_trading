import 'package:flutter/material.dart';
import '../../../shared/theme/font_helper.dart';

import '../../shared/constants/app_constants.dart';

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXxs,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppConstants.defaultAnimationDuration,
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: colorScheme.secondary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(children: [
              Icon(icon, size: 22, color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.65)),
              const SizedBox(width: AppConstants.spacingSm),
              Text(label, style: inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}
