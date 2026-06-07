import 'package:equatable/equatable.dart';

sealed class KisAccountEvent extends Equatable {
  const KisAccountEvent();
  @override
  List<Object?> get props => [];
}

class KisAccountFetchRequested extends KisAccountEvent {
  final String accountNo;
  final String productCode;
  final bool isPaper;

  const KisAccountFetchRequested({
    required this.accountNo,
    required this.productCode,
    required this.isPaper,
  });

  @override
  List<Object?> get props => [accountNo, productCode, isPaper];
}
