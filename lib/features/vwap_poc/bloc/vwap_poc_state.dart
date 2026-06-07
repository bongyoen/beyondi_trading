import 'package:equatable/equatable.dart';

import 'package:beyondi_trading/features/vwap_poc/model/dto/vwap_poc_item.dart';

abstract class VwapPocState extends Equatable {
  const VwapPocState();

  @override
  List<Object?> get props => [];
}

class VwapPocInitial extends VwapPocState {
  const VwapPocInitial();
}

class VwapPocLoading extends VwapPocState {
  const VwapPocLoading();
}

class VwapPocLoaded extends VwapPocState {
  final List<VwapPocItem> items;
  final DateTime lastUpdated;

  const VwapPocLoaded({required this.items, required this.lastUpdated});

  @override
  List<Object?> get props => [items, lastUpdated];
}

class VwapPocFailure extends VwapPocState {
  final String message;

  const VwapPocFailure(this.message);

  @override
  List<Object?> get props => [message];
}
