import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/entities/account_balance/model/account_balance.dart';
import 'package:beyondi_trading/entities/asset_summary/model/asset_summary.dart';
import 'package:beyondi_trading/entities/buy_power/model/buy_power.dart';
import 'package:beyondi_trading/entities/period_profit_loss/model/period_profit_loss.dart';

class KisAccountRepository {
  KisAccountRepository({required KisStockApi api}) : _api = api;

  final KisStockApi _api;

  Future<AccountBalance> getBalance({
    required String accountNo,
    required String productCode,
  }) async {
    final (holdings, summary) = await _api.fetchBalance(
      accountNo: accountNo,
      productCode: productCode,
    );
    return AccountBalance(
      totalAsset: _firstOf(summary, ['tota_assamt', 'tot_evlu_amt', 'prs_amt']),
      stockEvaluation: _firstOf(summary, ['scts_evlu_amt', 'evlu_amt_smtl_amt']),
      evaluationProfitLoss: _firstOf(summary, ['evlu_pfls_smtl_amt', 'pfls_amt']),
      evaluationProfitRate: _firstOf(summary, ['evlu_tota_erng_rt', 'bfm_erng_rt']),
      deposit: _firstOf(summary, ['dnca_tot_amt', 'dnst_tot_amt', 'dnca_amt']),
      d1Deposit: _firstOf(summary, ['nxdy_exc_amt', 'nxdy_amt']),
      d2Deposit: _firstOf(summary, ['prvs_rcdl_exc_amt', 'prvs_amt']),
      purchaseAmount: _firstOf(summary, ['pchs_amt_smtl_amt', 'pchs_amt']),
      evaluationAmount: _firstOf(summary, ['evlu_amt_smtl_amt', 'evlu_amt']),
      holdings: holdings.map((e) => StockHolding.fromJson(e)).toList(),
    );
  }

  Future<AssetSummary> getAssetSummary({
    required String accountNo,
    required String productCode,
  }) async {
    final (out1, _) = await _api.fetchAccountAssetSummary(
      accountNo: accountNo,
      productCode: productCode,
    );
    return AssetSummary.fromJson(out1);
  }

  Future<BuyPower> getBuyPower({
    required String accountNo,
    required String productCode,
  }) async {
    final out = await _api.fetchBuyPower(
      accountNo: accountNo,
      productCode: productCode,
    );
    return BuyPower.fromJson(out);
  }

  Future<PeriodProfitLoss> getPeriodProfitLoss({
    required String accountNo,
    required String productCode,
    required String startDate,
    required String endDate,
  }) async {
    final (out1, _) = await _api.fetchPeriodTradeProfit(
      accountNo: accountNo,
      productCode: productCode,
      startDate: startDate,
      endDate: endDate,
    );
    return PeriodProfitLoss.fromJson(out1);
  }

  static double _firstOf(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final parsed = double.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}
