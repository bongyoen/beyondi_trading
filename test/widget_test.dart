import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beyondi_trading/app/app.dart';
import 'package:beyondi_trading/features/auth/api/auth_repository.dart';
import 'package:beyondi_trading/features/auth/bloc/login_bloc.dart';
import 'package:beyondi_trading/features/counter/bloc/counter_bloc.dart';

void main() {
  testWidgets('App renders login page on startup', (WidgetTester tester) async {
    await tester.pumpWidget(
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

    // Verify that the login page is shown on startup.
    expect(find.text('Beyondi Trading'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);

    // Verify that the form fields are present.
    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify that the Sign In button is present.
    expect(find.text('Sign In'), findsOneWidget);
  });
}
