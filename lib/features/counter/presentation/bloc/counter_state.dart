import 'package:equatable/equatable.dart';

/// Possible states of the counter feature.
///
/// Using sealed class guarantees exhaustive matching in the UI layer,
/// making illegal states unrepresentable.
sealed class CounterState extends Equatable {
  const CounterState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any interaction.
final class CounterInitial extends CounterState {
  const CounterInitial();
}

/// State representing the current counter value.
final class CounterValueState extends CounterState {
  const CounterValueState(this.value);

  /// The current count value.
  final int value;

  @override
  List<Object?> get props => [value];
}
