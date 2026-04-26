import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/counter/presentation/bloc/counter_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CounterBloc()),
        BlocProvider(
          create: (_) => LoginBloc(
            authRepository: DemoAuthRepository(),
          ),
        ),
      ],
      child: const BeyondiTradingApp(),
    ),
  );
}
