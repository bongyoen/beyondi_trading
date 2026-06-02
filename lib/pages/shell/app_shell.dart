import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../entities/user.dart';
import '../../../features/auth/presentation/bloc/login_state.dart';
import '../../../features/auth/presentation/bloc/login_bloc.dart';
import '../../../features/kis_auth/presentation/widgets/kis_status_badge.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../widgets/sidebar/responsive_sidebar.dart';
import '../backtest/backtest_page.dart';
import '../home/home_page.dart';
import '../ui_components/ui_components_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static Widget _ph(String title, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Text('준비 중', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.withValues(alpha: 0.4))),
      ]),
    );
  }

  List<Widget> get _pages => [
    const HomePage(),
    _ph('포트폴리오', Icons.pie_chart_rounded),
    _ph('마켓', Icons.show_chart_rounded),
    _ph('거래', Icons.swap_horiz_rounded),
    _ph('분석', Icons.analytics_rounded),
    const BacktestPage(),
    const UiComponentsPage(),
    _ph('설정', Icons.settings_rounded),
  ];

  static const List<String> _titles = [
    '대시보드', '포트폴리오', '마켓', '거래', '분석', '백테스트', 'UI 컴포넌트', '설정',
  ];

  User? get _user {
    final s = context.read<LoginBloc>().state;
    return s is LoginSuccess ? s.user : null;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < AppConstants.mobileBreakpoint;
    return LayoutBuilder(
      builder: (_, __) => mobile ? _mobile() : _desktop(),
    );
  }

  Widget _desktop() {
    return Row(children: [
      SizedBox(
        width: AppConstants.sidebarWidth,
        child: ResponsiveSidebar(
          currentIndex: _selectedIndex,
          onItemSelected: (i) => setState(() => _selectedIndex = i),
        ),
      ),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.surfaceGradient(Theme.of(context).brightness == Brightness.dark),
          ),
          child: SafeArea(
            child: Column(children: [
              _topBar(),
              Expanded(child: _body()),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _mobile() {
    final key = GlobalKey<ScaffoldState>();
    return Scaffold(
      key: key,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => key.currentState?.openDrawer(),
        ),
        title: Text(_titles[_selectedIndex]),
        actions: [
          _kis(),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      drawer: Drawer(
        child: ResponsiveSidebar(
          currentIndex: _selectedIndex,
          onItemSelected: (i) {
            setState(() => _selectedIndex = i);
            Navigator.of(context).pop();
          },
        ).showAsDrawer(context),
      ),
      body: _body(),
    );
  }

  Widget _kis() {
    final u = _user;
    return u == null ? const SizedBox() : KisStatusBadge(user: u);
  }

  Widget _topBar() {
    final cs = Theme.of(context).colorScheme;
    final name = _user?.name ?? '트레이더';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
      ),
      child: Row(children: [
        Text('Beyondi Trading', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(width: 12),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () {
            final maxIdx = _titles.length - 1;
            setState(() => _selectedIndex = _selectedIndex >= maxIdx ? 0 : _selectedIndex + 1);
          },
          child: Text('$_selectedIndex', style: TextStyle(fontSize: 11, color: cs.primary)),
        ),
        Spacer(),
        Text('$name 님', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
        SizedBox(width: 8),
        _kis(),
        SizedBox(width: 4),
        IconButton(icon: Icon(Icons.notifications_outlined, size: 20, color: cs.onSurfaceVariant), onPressed: () {}),
      ]),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: IndexedStack(index: _selectedIndex, children: _pages),
    );
  }
}
