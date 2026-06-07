import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/features/auth/bloc/login_bloc.dart';
import 'package:beyondi_trading/features/auth/bloc/login_state.dart';
// Moved to pages/auth/login/ui/
import 'package:beyondi_trading/pages/auth/login/ui/login_page.dart';
import 'package:beyondi_trading/pages/shell/index.dart';
import 'package:beyondi_trading/shared/theme/app_theme.dart';

// ?곥꽩?뉎뀅?담뀋
/// Root application widget.
///
/// Provides theme configuration and top-level auth-aware routing.
/// Displays [LoginPage] when unauthenticated and [AppShell] when
/// authentication succeeds.
class BeyondiTradingApp extends StatelessWidget {
  const BeyondiTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beyondi Trading',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: BlocBuilder<LoginBloc, LoginState>(
        builder: (context, state) {
          return switch (state) {
            LoginSuccess() => const AppShell(),
            _ => const LoginPage(),
          };
        },
      ),
    );
  }
}
