import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'package:beyondi_trading/features/auth/api/auth_repository.dart';
import 'package:beyondi_trading/features/auth/bloc/login_bloc.dart';
import 'package:beyondi_trading/features/counter/bloc/counter_bloc.dart';
import 'features/kis_auth/api/kis_auth_repository.dart';
import 'features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/stock_search/bloc/stock_search_cubit.dart';

import 'shared/api/api_client.dart';
import 'shared/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Dependency Setup ────────────────────────────────────────────────
  //
  // Choose between the demo and live API based on environment config.
  // Override with --dart-define=USE_DEMO_AUTH=true for offline development.
  final AuthRepository authRepository = AppConfig.useDemoAuth
      ? const DemoAuthRepository()
      : WorkersAuthRepository(
          apiClient: ApiClient(baseUrl: AppConfig.apiBaseUrl),
        );

  final KisAuthRepository kisAuthRepository = WorkersKisAuthRepository(
    apiBaseUrl: AppConfig.apiBaseUrl,
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CounterBloc()),
        BlocProvider(
          create: (_) => LoginBloc(authRepository: authRepository),
        ),
        BlocProvider(
          create: (_) => KisAuthBloc(repository: kisAuthRepository),
        ),
        BlocProvider(create: (_) => StockSearchCubit()),
      ],
      child: const BeyondiTradingApp(),
    ),
  );
}
