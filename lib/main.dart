import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/counter/presentation/bloc/counter_bloc.dart';
import 'features/kis_auth/data/repositories/kis_auth_repository.dart';
import 'features/kis_auth/presentation/bloc/kis_auth_bloc.dart';

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
      ],
      child: const BeyondiTradingApp(),
    ),
  );
}
