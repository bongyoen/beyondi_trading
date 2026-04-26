import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/counter.dart';
import '../../domain/usecases/increment_counter.dart';
import 'counter_event.dart';
import 'counter_state.dart';

/// Business logic component for the counter feature.
///
/// Handles [CounterEvent]s and emits [CounterState]s. Pure business
/// logic is extracted to domain use cases, keeping the bloc focused
/// on orchestration.
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterInitial()) {
    on<CounterIncrementPressed>(_onIncrementPressed);
  }

  /// Handles the [CounterIncrementPressed] event.
  ///
  /// Uses the pure [incrementCounter] use case to compute the next
  /// state, ensuring atomic predictability.
  Future<void> _onIncrementPressed(
    CounterIncrementPressed event,
    Emitter<CounterState> emit,
  ) async {
    // Parse current value from state, guarding against invalid states.
    final currentValue = switch (state) {
      CounterInitial() => 0,
      CounterValueState(:final value) => value,
    };

    final counter = CounterValue(currentValue);
    final incremented = incrementCounter(counter);

    emit(CounterValueState(incremented.value));
  }
}
