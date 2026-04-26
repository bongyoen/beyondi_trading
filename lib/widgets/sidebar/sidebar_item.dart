import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/constants/app_constants.dart';

/// A single navigation item within the sidebar.
///
/// Visually distinct when selected, with a bold accent indicator and
/// smooth hover feedback on desktop.
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// Leading icon for the navigation item.
  final IconData icon;

  /// Display label text.
  final String label;

  /// Whether this item is currently selected.
  final bool isSelected;

  /// Called when the item is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXxs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          splashColor: colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
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
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
