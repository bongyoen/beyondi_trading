import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../entities/user.dart';
import '../../../features/auth/presentation/bloc/login_state.dart';
import '../../../features/auth/presentation/bloc/login_bloc.dart';
import '../../../features/kis_auth/presentation/bloc/kis_auth_bloc.dart';
import '../../../features/kis_auth/presentation/bloc/kis_auth_event.dart';
import '../../../features/kis_auth/presentation/widgets/kis_status_badge.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../widgets/sidebar/responsive_sidebar.dart';
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
      _buildPlaceholder('포트폴리오', Icons.pie_chart_rounded),
      _buildPlaceholder('마켓', Icons.show_chart_rounded),
      _buildPlaceholder('거래', Icons.swap_horiz_rounded),
      _buildPlaceholder('분석', Icons.analytics_rounded),
      _buildPlaceholder('설정', Icons.settings_rounded),
    ];
    _loadKisStatus();
  }

  void _loadKisStatus() {
    final authState = context.read<LoginBloc>().state;
    if (authState is LoginSuccess) {
      context.read<KisAuthBloc>().add(KisStatusRequested(userId: authState.user.id));
    }
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

  /// Desktop layout: fixed sidebar + header bar + content.
  Widget _buildDesktopLayout() {
    final user = _currentUser;

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

        // ── Main Area (Header + Content) ──
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.surfaceGradient(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeaderBar(user),
                  Expanded(child: _buildContentArea()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  User? get _currentUser {
    final authState = context.read<LoginBloc>().state;
    return authState is LoginSuccess ? authState.user : null;
  }

  /// KIS 상태 뱃지 (연결/미연결/오류).
  Widget _kisBadge() {
    final user = _currentUser;
    if (user == null) return const SizedBox.shrink();
    return KisStatusBadge(user: user);
  }

  /// 상단 헤더 바 — 사용자 인사말 + KIS 연결 상태.
  Widget _buildHeaderBar(User? user) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = user?.name ?? '트레이더';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, size: 20, color: colorScheme.primary),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            'Beyondi Trading',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            '$displayName 님',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          _kisBadge(),
          const SizedBox(width: AppConstants.spacingSm),
          IconButton(
            icon: Icon(Icons.notifications_outlined, size: 20, color: colorScheme.onSurfaceVariant),
            onPressed: () {},
            tooltip: '알림',
          ),
        ],
      ),
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
          tooltip: '메뉴 열기',
        ),
        title: Text(_pagesTitle[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _kisBadge(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: '알림',
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
    if (index >= 0 && index < _pages.length) {
      setState(() => _selectedIndex = index);
    }
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
            '준비 중',
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
    '대시보드',
    '포트폴리오',
    '마켓',
    '거래',
    '분석',
    '설정',
  ];
}
