import 'package:equatable/equatable.dart';

/// Events dispatched to the [CounterBloc].
///
/// Using sealed class ensures exhaustive handling and prevents
/// illegal states (Parse Don't Validate).
sealed class CounterEvent extends Equatable {
  const CounterEvent();

  @override
  List<Object?> get props => [];
}

/// Event indicating the counter should be incremented.
final class CounterIncrementPressed extends CounterEvent {
  const CounterIncrementPressed();
}
