import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/constants/app_constants.dart';
import '../../shared/theme/app_theme.dart';
import '../../widgets/sidebar/responsive_sidebar.dart';
import '../home/home_page.dart';

/// Responsive application shell with a persistent sidebar on desktop
/// and a drawer-based navigation on mobile.
///
/// Adapts to screen width using [AppConstants.mobileBreakpoint]:
/// - Desktop (>= 768px): Fixed sidebar + content area
/// - Mobile (< 768px): Hamburger menu + Drawer sidebar
///
/// Follows the 5 Pillars:
/// - Typography: Poppins headings, Inter body
/// - Color: Bold sidebar gradient vs clean content surface
/// - Motion: Smooth sidebar entrance, drawer slide, content transitions
/// - Space: Generous content padding, controlled sidebar density
/// - Depth: Sidebar gradient shadow, content subtle surface gradient
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      _buildPlaceholder('Portfolio', Icons.pie_chart_rounded),
      _buildPlaceholder('Markets', Icons.show_chart_rounded),
      _buildPlaceholder('Trade', Icons.swap_horiz_rounded),
      _buildPlaceholder('Analytics', Icons.analytics_rounded),
      _buildPlaceholder('Settings', Icons.settings_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.mobileBreakpoint;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) {
          return _buildMobileLayout();
        }
        return _buildDesktopLayout();
      },
    );
  }

  /// Desktop layout: fixed sidebar + expanded content.
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // ── Persistent Sidebar ──
        SizedBox(
          width: AppConstants.sidebarWidth,
          child: ResponsiveSidebar(
            currentIndex: _selectedIndex,
            onItemSelected: _onItemSelected,
          ),
        ),

        // ── Main Content ──
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.surfaceGradient(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            child: SafeArea(
              child: _buildContentArea(),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout: scaffold with drawer and app bar.
  Widget _buildMobileLayout() {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Open menu',
        ),
        title: Text(
          _pagesTitle[_selectedIndex],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      drawer: Drawer(
        child: ResponsiveSidebar(
          currentIndex: _selectedIndex,
          onItemSelected: (index) {
            _onItemSelected(index);
            Navigator.of(context).pop(); // Close drawer
          },
        ).showAsDrawer(context),
      ),
      body: _buildContentArea(),
    );
  }

  /// Shared content area with animated page switching.
  Widget _buildContentArea() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: AnimatedSwitcher(
        duration: AppConstants.defaultAnimationDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
    );
  }

  void _onItemSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  static Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            'Coming soon',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _pagesTitle = [
    'Dashboard',
    'Portfolio',
    'Markets',
    'Trade',
    'Analytics',
    'Settings',
  ];
}
