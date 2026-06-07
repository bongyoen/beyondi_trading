import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';
import 'package:beyondi_trading/entities/user/model/user.dart';
import 'package:beyondi_trading/features/auth/bloc/login_state.dart';
import 'package:beyondi_trading/features/auth/bloc/login_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_event.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_state.dart';
import 'package:beyondi_trading/widgets/kis_status_badge/ui/kis_status_badge.dart';
import 'package:beyondi_trading/shared/constants/app_constants.dart';
import 'package:beyondi_trading/shared/theme/app_theme.dart';
import 'package:beyondi_trading/widgets/sidebar/ui/responsive_sidebar.dart';
import 'package:beyondi_trading/features/auto_trade/bloc/auto_trade_bloc.dart';
import 'package:beyondi_trading/pages/auto_trade/index.dart';
import 'package:beyondi_trading/pages/analysis/index.dart';
import 'package:beyondi_trading/pages/backtest/index.dart';
import 'package:beyondi_trading/pages/home/index.dart';
import 'package:beyondi_trading/pages/trading/index.dart';
import 'package:beyondi_trading/pages/ui_components/index.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AutoTradeBloc _autoTradeBloc = AutoTradeBloc();
  int _selectedIndex = 0;
  bool _justRefreshed = false;

  static Widget _ph(String title, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(title, style: poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Text('준비 중', style: inter(fontSize: 14, color: Colors.grey.withValues(alpha: 0.4))),
      ]),
    );
  }

  List<Widget> get _pages => [
    const HomePage(),
    _ph('포트폴리오', Icons.pie_chart_rounded),
    _ph('마켓', Icons.show_chart_rounded),
    const TradingPage(),
    const AutoTradePage(),
    const AnalysisPage(),
    const BacktestPage(),
    const UiComponentsPage(),
    _ph('설정', Icons.settings_rounded),
  ];

  static const List<String> _titles = [
    '대시보드', '포트폴리오', '마켓', '거래', '자동거래', '분석', '백테스트', 'UI 컴포넌트', '설정',
  ];

  User? get _user {
    final s = context.read<LoginBloc>().state;
    return s is LoginSuccess ? s.user : null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _autoTradeBloc,
      child: Scaffold(
      body: BlocListener<KisAuthBloc, KisAuthState>(
        listener: (ctx, state) {
        if (_justRefreshed && state is KisAuthConnected) {
          _justRefreshed = false;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: const Text('토큰 갱신 완료'), duration: const Duration(seconds: 2)),
          );
        }
        if (_justRefreshed && state is KisAuthFailure) {
          _justRefreshed = false;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.orange.shade700, duration: const Duration(seconds: 3)),
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, _) {
          final mobile = MediaQuery.of(context).size.width < AppConstants.mobileBreakpoint;
          return mobile ? _mobile() : _desktop();
        },
      ),
    ),
    ),
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
        Text('Beyondi Trading', style: poppins(fontSize: 16, fontWeight: FontWeight.w700)),
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
        Text('$name 님', style: inter(fontSize: 13, color: cs.onSurfaceVariant)),
        SizedBox(width: 8),
        _kis(),
        if (_user != null)
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 16, color: cs.onSurfaceVariant),
            tooltip: 'KIS 토큰 갱신',
            onPressed: () {
              _justRefreshed = true;
              context.read<KisAuthBloc>().add(KisRefreshRequested(userId: _user!.id));
            },
          ),
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
