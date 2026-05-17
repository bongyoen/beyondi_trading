import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/counter_bloc.dart';
import '../bloc/counter_event.dart';
import '../bloc/counter_state.dart';

/// UI component for the counter feature.
///
/// Displays the current counter value and an increment button.
/// Listens to [CounterBloc] state changes reactively.
class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CounterBloc, CounterState>(
      builder: (context, state) {
        final count = switch (state) {
          CounterInitial() => 0,
          CounterValueState(:final value) => value,
        };

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('버튼을 이만큼 누르셨습니다:'),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () {
                context.read<CounterBloc>().add(
                  const CounterIncrementPressed(),
                );
              },
              tooltip: '증가',
              child: const Icon(Icons.add),
            ),
          ],
        );
      },
    );
  }
}
