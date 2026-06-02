import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/constants/app_constants.dart';
import '../../shared/theme/app_theme.dart';
import '../../entities/user.dart';
import 'sidebar_item.dart';

/// Navigation section labels for categorizing sidebar items.
enum SidebarSection { main, tools, account }

/// A single navigation destination.
class _SidebarDestination {
  const _SidebarDestination({
    required this.icon,
    required this.label,
    required this.section,
  });

  final IconData icon;
  final String label;
  final SidebarSection section;
}

/// All sidebar navigation destinations.
const List<_SidebarDestination> _destinations = [
  _SidebarDestination(
    icon: Icons.dashboard_rounded,
    label: '대시보드',
    section: SidebarSection.main,
  ),
  _SidebarDestination(
    icon: Icons.pie_chart_rounded,
    label: '포트폴리오',
    section: SidebarSection.main,
  ),
  _SidebarDestination(
    icon: Icons.show_chart_rounded,
    label: '마켓',
    section: SidebarSection.main,
  ),
  _SidebarDestination(
    icon: Icons.swap_horiz_rounded,
    label: '거래',
    section: SidebarSection.tools,
  ),
  _SidebarDestination(
    icon: Icons.analytics_rounded,
    label: '분석',
    section: SidebarSection.tools,
  ),
  _SidebarDestination(
    icon: Icons.science_rounded,
    label: '백테스트',
    section: SidebarSection.tools,
  ),
  _SidebarDestination(
    icon: Icons.palette_rounded,
    label: 'UI 컴포넌트',
    section: SidebarSection.account,
  ),
  _SidebarDestination(
    icon: Icons.settings_rounded,
    label: '설정',
    section: SidebarSection.account,
  ),
];

/// Responsive sidebar that adapts to screen size.
///
/// Desktop: Fixed sidebar panel with AnimatedContainer for smooth
///          entrance and hover effects.
/// Mobile:  Triggered via [showAsDrawer] which returns a [Drawer].
///
/// Follows the 5 Pillars:
/// - Typography: Poppins (logo), Inter (items)
/// - Color: Deep gradient background with gold accent for active item
/// - Motion: Smooth slide + fade on render, AnimatedContainer for items
/// - Space: Generous padding between sections
/// - Depth: Gradient background, shadow, selected-item glow
class ResponsiveSidebar extends StatefulWidget {
  const ResponsiveSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.user,
  });

  /// Currently selected destination index.
  final int currentIndex;

  /// Called with the index of the tapped item.
  final ValueChanged<int> onItemSelected;

  /// Optional user to show profile section at bottom.
  final User? user;

  /// Returns the sidebar as a [Drawer] widget (for mobile use).
  Widget showAsDrawer(BuildContext context) {
    return Drawer(
      child: _SidebarContent(
        currentIndex: currentIndex,
        onItemSelected: onItemSelected,
        user: user,
      ),
    );
  }

  @override
  State<ResponsiveSidebar> createState() => _ResponsiveSidebarState();
}

class _ResponsiveSidebarState extends State<ResponsiveSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: AppConstants.sidebarAnimationDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _SidebarContent(
          currentIndex: widget.currentIndex,
          onItemSelected: widget.onItemSelected,
          user: widget.user,
        ),
      ),
    );
  }
}

/// Internal sidebar content shared between desktop and drawer variants.
class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.currentIndex,
    required this.onItemSelected,
    this.user,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: AppConstants.sidebarWidth,
      decoration: BoxDecoration(
        gradient: AppTheme.sidebarGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Brand Header ──
          _buildHeader(colorScheme),
          const Divider(height: 1),

          // ── Navigation Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: AppConstants.spacingSm),
              children: _buildSections(colorScheme, 0),
            ),
          ),

          // ── User Profile ──
          _buildUserProfile(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingXl,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.buttonGradient,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            'Beyondi',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(ColorScheme colorScheme, int startIndex) {
    final List<Widget> sections = [];
    int destIndex = startIndex;

    for (final section in SidebarSection.values) {
      final items = _destinations
          .where((d) => d.section == section)
          .toList();

      if (items.isEmpty) continue;

      // Section label
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingSm,
            AppConstants.spacingMd,
            AppConstants.spacingXxs,
          ),
          child: Text(
            _sectionLabel(section),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
        ),
      );

      // Items in this section
      for (final dest in items) {
        final idx = destIndex;
        sections.add(
          SidebarItem(
            icon: dest.icon,
            label: dest.label,
            isSelected: currentIndex == idx,
            onTap: () => onItemSelected(idx),
          ),
        );
        destIndex++;
      }

      sections.add(const SizedBox(height: AppConstants.spacingXs));
    }

    return sections;
  }

  String _sectionLabel(SidebarSection section) {
    return switch (section) {
      SidebarSection.main => 'MAIN',
      SidebarSection.tools => 'TOOLS',
      SidebarSection.account => 'ACCOUNT',
    };
  }

  Widget _buildUserProfile(ColorScheme colorScheme) {
    final String displayName = user?.name ?? '게스트';
    final String displayEmail = user?.email ?? 'guest@beyondi.com';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.secondary.withValues(alpha: 0.2),
            child: Text(
              displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : 'G',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  displayEmail,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.logout_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
