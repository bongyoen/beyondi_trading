import 'package:equatable/equatable.dart';

sealed class CounterEvent extends Equatable {
  const CounterEvent();

  @override
  List<Object?> get props => [];
}

final class CounterIncrementPressed extends CounterEvent {
  const CounterIncrementPressed();
}
