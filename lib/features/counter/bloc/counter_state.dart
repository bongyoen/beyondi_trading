import 'package:equatable/equatable.dart';

sealed class CounterState extends Equatable {
  const CounterState();

  @override
  List<Object?> get props => [];
}

final class CounterInitial extends CounterState {
  const CounterInitial();
}

final class CounterValueState extends CounterState {
  const CounterValueState(this.value);

  final int value;

  @override
  List<Object?> get props => [value];
}
