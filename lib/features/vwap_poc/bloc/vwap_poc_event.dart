import 'package:equatable/equatable.dart';

abstract class VwapPocEvent extends Equatable {
  const VwapPocEvent();

  @override
  List<Object?> get props => [];
}

class VwapPocRequested extends VwapPocEvent {
  const VwapPocRequested();
}

class VwapPocRefreshRequested extends VwapPocEvent {
  const VwapPocRefreshRequested();
}
