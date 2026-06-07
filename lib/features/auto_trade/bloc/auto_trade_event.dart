import 'package:equatable/equatable.dart';

abstract class AutoTradeEvent extends Equatable {
  const AutoTradeEvent();
  @override
  List<Object?> get props => [];
}

class LoadItems extends AutoTradeEvent {
  const LoadItems();
}

class AddItem extends AutoTradeEvent {
  final String code;
  final String name;
  const AddItem({required this.code, required this.name});
  @override
  List<Object?> get props => [code, name];
}

class RemoveItem extends AutoTradeEvent {
  final String code;
  const RemoveItem(this.code);
  @override
  List<Object?> get props => [code];
}

class UpdateAmount extends AutoTradeEvent {
  final String code;
  final int amount;
  const UpdateAmount({required this.code, required this.amount});
  @override
  List<Object?> get props => [code, amount];
}

class SetMode extends AutoTradeEvent {
  final bool isPaper;
  const SetMode(this.isPaper);
  @override
  List<Object?> get props => [isPaper];
}

class ItemStart extends AutoTradeEvent {
  final String code;
  const ItemStart(this.code);
  @override
  List<Object?> get props => [code];
}

class ItemStop extends AutoTradeEvent {
  final String code;
  const ItemStop(this.code);
  @override
  List<Object?> get props => [code];
}

class ItemPause extends AutoTradeEvent {
  final String code;
  const ItemPause(this.code);
  @override
  List<Object?> get props => [code];
}

class BatchStart extends AutoTradeEvent {
  const BatchStart();
}

class BatchStop extends AutoTradeEvent {
  const BatchStop();
}

class CheckSellTime extends AutoTradeEvent {
  const CheckSellTime();
}

class RefreshPrices extends AutoTradeEvent {
  const RefreshPrices();
}
