import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/kis_account_repository.dart';
import '../../domain/entities/asset_summary.dart';
import '../../domain/entities/buy_power.dart';
import '../../domain/entities/period_profit_loss.dart';
import 'kis_account_event.dart';
import 'kis_account_state.dart';

class KisAccountBloc extends Bloc<KisAccountEvent, KisAccountState> {
  KisAccountBloc({required KisAccountRepository repository})
      : _repository = repository,
        super(const KisAccountInitial()) {
    on<KisAccountFetchRequested>(_onFetch);
  }

  final KisAccountRepository _repository;

  Future<void> _onFetch(
    KisAccountFetchRequested event,
    Emitter<KisAccountState> emit,
  ) async {
    emit(const KisAccountLoading());
    try {
      final balance = await _repository.getBalance(
        accountNo: event.accountNo,
        productCode: event.productCode,
      );

      AssetSummary? assetSummary;
      BuyPower? buyPower;
      PeriodProfitLoss? periodProfitLoss;

      if (!event.isPaper) {
        try {
          assetSummary = await _repository.getAssetSummary(
            accountNo: event.accountNo,
            productCode: event.productCode,
          );
        } catch (_) {}
        try {
          buyPower = await _repository.getBuyPower(
            accountNo: event.accountNo,
            productCode: event.productCode,
          );
        } catch (_) {}
        try {
          final today = DateTime.now();
          final start = today.subtract(const Duration(days: 30));
          periodProfitLoss = await _repository.getPeriodProfitLoss(
            accountNo: event.accountNo,
            productCode: event.productCode,
            startDate:
                '${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}',
            endDate:
                '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}',
          );
        } catch (_) {}
      }

      emit(KisAccountLoaded(
        balance: balance,
        assetSummary: assetSummary,
        buyPower: buyPower,
        periodProfitLoss: periodProfitLoss,
      ));
    } catch (e) {
      emit(KisAccountFailure(message: e.toString()));
    }
  }
}
