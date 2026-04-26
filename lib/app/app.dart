import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/login_bloc.dart';
import '../features/auth/presentation/bloc/login_state.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../pages/shell/app_shell.dart';
import '../shared/theme/app_theme.dart';

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
