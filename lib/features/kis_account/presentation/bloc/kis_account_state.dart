import 'package:equatable/equatable.dart';

import '../../domain/entities/account_balance.dart';
import '../../domain/entities/asset_summary.dart';
import '../../domain/entities/buy_power.dart';
import '../../domain/entities/period_profit_loss.dart';

sealed class KisAccountState extends Equatable {
  const KisAccountState();
  @override
  List<Object?> get props => [];
}

class KisAccountInitial extends KisAccountState {
  const KisAccountInitial();
}

class KisAccountLoading extends KisAccountState {
  const KisAccountLoading();
}

class KisAccountLoaded extends KisAccountState {
  final AccountBalance balance;
  final AssetSummary? assetSummary;
  final BuyPower? buyPower;
  final PeriodProfitLoss? periodProfitLoss;
  final String? error;

  const KisAccountLoaded({
    required this.balance,
    this.assetSummary,
    this.buyPower,
    this.periodProfitLoss,
    this.error,
  });

  KisAccountLoaded copyWith({
    AccountBalance? balance,
    AssetSummary? assetSummary,
    BuyPower? buyPower,
    PeriodProfitLoss? periodProfitLoss,
    String? error,
  }) {
    return KisAccountLoaded(
      balance: balance ?? this.balance,
      assetSummary: assetSummary ?? this.assetSummary,
      buyPower: buyPower ?? this.buyPower,
      periodProfitLoss: periodProfitLoss ?? this.periodProfitLoss,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [balance, assetSummary, buyPower, periodProfitLoss, error];
}

class KisAccountFailure extends KisAccountState {
  final String message;
  const KisAccountFailure({required this.message});
  @override
  List<Object?> get props => [message];
}
