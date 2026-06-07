import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/entities/counter/model/counter.dart';
import 'package:beyondi_trading/features/counter/model/usecases/increment_counter.dart';
import 'package:beyondi_trading/features/counter/bloc/counter_event.dart';
import 'package:beyondi_trading/features/counter/bloc/counter_state.dart';

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterInitial()) {
    on<CounterIncrementPressed>(_onIncrementPressed);
  }

  Future<void> _onIncrementPressed(
    CounterIncrementPressed event,
    Emitter<CounterState> emit,
  ) async {
    final currentValue = switch (state) {
      CounterInitial() => 0,
      CounterValueState(:final value) => value,
    };

    final counter = CounterValue(currentValue);
    final incremented = incrementCounter(counter);

    emit(CounterValueState(incremented.value));
  }
}
