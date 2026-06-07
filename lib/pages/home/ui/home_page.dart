import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/features/kis_account/api/kis_account_repository.dart';
import 'package:beyondi_trading/entities/account_balance/model/account_balance.dart';
import 'package:beyondi_trading/entities/asset_summary/model/asset_summary.dart';
import 'package:beyondi_trading/entities/buy_power/model/buy_power.dart';
import 'package:beyondi_trading/entities/period_profit_loss/model/period_profit_loss.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_state.dart';
import 'package:beyondi_trading/features/vwap_poc/model/dto/vwap_poc_item.dart';
import 'package:beyondi_trading/features/vwap_poc/bloc/vwap_poc_bloc.dart';
import 'package:beyondi_trading/features/vwap_poc/bloc/vwap_poc_event.dart';
import 'package:beyondi_trading/features/vwap_poc/bloc/vwap_poc_state.dart';
import 'package:beyondi_trading/shared/constants/app_constants.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VwapPocBloc _vwapPocBloc = VwapPocBloc();
  KisAccountRepository? _repo;
  bool _loading = false;
  AccountBalance? _balance;
  AssetSummary? _assetSummary;
  BuyPower? _buyPower;
  PeriodProfitLoss? _periodProfitLoss;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<KisAuthBloc>().state;
      if (authState is KisAuthConnected) {
        final creds = authState.connection.active;
        if (creds != null) {
          final api = KisStockApi(
            appKey: creds.appKey,
            appSecret: creds.appSecret,
            isPaper: authState.connection.useMock,
          );
          if (creds.accessToken != null && creds.tokenExpiry != null) {
            api.setToken(creds.accessToken!, creds.tokenExpiry!);
          }
          _vwapPocBloc.setApi(api);
          _vwapPocBloc.add(const VwapPocRequested());
        }
      }
    });
  }

  @override
  void dispose() {
    _vwapPocBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authState = context.watch<KisAuthBloc>().state;
    final connected = authState is KisAuthConnected && authState.connection.isTokenValid;
    final conn = authState is KisAuthConnected ? authState.connection : null;
    final creds = conn?.active;
    final hasAccount = creds?.accountNo != null;

    _ensureFetch(authState);

    return BlocProvider.value(
      value: _vwapPocBloc,
      child: ListView(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      children: [
        _welcomeCard(cs, connected, conn?.envLabel ?? ''),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
            child: Text(_error!, style: inter(fontSize: 11, color: Colors.red.shade800)),
          ),
        ],
        if (connected && hasAccount && !_loading && _balance != null) ...[
          const SizedBox(height: AppConstants.spacingLg),
          _assetCards(cs),
          const SizedBox(height: AppConstants.spacingLg),
          if (_balance!.holdings.isNotEmpty) _holdingsTable(cs),
        ] else if (connected && !hasAccount) ...[
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('계좌번호를 입력하면 잔고 정보를 표시합니다. KIS 뱃지를 탭하여 설정하세요.',
                  style: inter(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
        ] else if (!connected) ...[
          const SizedBox(height: AppConstants.spacingLg),
          Row(children: [
            Expanded(child: _statCard(cs, '포트폴리오 가치', '₩0', Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(cs, '오늘의 손익', '₩0', Icons.trending_up_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(cs, '진행 중 포지션', '0', Icons.swap_horiz_rounded)),
          ]),
        ],
        BlocBuilder<VwapPocBloc, VwapPocState>(
          builder: (ctx, vwapState) {
            if (vwapState is VwapPocLoaded && vwapState.items.isNotEmpty) {
              return Column(children: [
                const SizedBox(height: AppConstants.spacingLg),
                _vwapPocRecommendationCard(cs, vwapState.items),
              ]);
            }
            if (vwapState is VwapPocFailure) {
              return Column(children: [
                const SizedBox(height: AppConstants.spacingLg),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(vwapState.message,
                      style: inter(fontSize: 11, color: Colors.red.shade800)),
                ),
              ]);
            }
            return const SizedBox.shrink();
          },
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ],
    ),
    );
  }

  String? _lastCredKey;

  void _ensureFetch(KisAuthState authState) {
    if (authState is KisAuthConnected) {
      final conn = authState.connection;
      final creds = conn.active;
      if (creds != null && (creds.accountNo?.isNotEmpty == true)) {
        final credKey = '${creds.appKey}|${creds.accountNo}|${conn.useMock}';
        final api = KisStockApi(
          appKey: creds.appKey,
          appSecret: creds.appSecret,
          isPaper: conn.useMock,
        );
        if (creds.accessToken != null && creds.tokenExpiry != null) {
          api.setToken(creds.accessToken!, creds.tokenExpiry!);
        }
        if (_lastCredKey != credKey) {
          _lastCredKey = credKey;
          _repo = KisAccountRepository(api: api);
          _balance = null;
          _assetSummary = null;
          _buyPower = null;
          _periodProfitLoss = null;
          _error = null;
          _fetch(creds.accountNo!, creds.productCode ?? '01', conn.useMock);
        }
      } else {
        _repo = null;
        _lastCredKey = null;
        _balance = null;
        _assetSummary = null;
        _buyPower = null;
        _periodProfitLoss = null;
        _error = null;
      }
    } else {
      _repo = null;
      _lastCredKey = null;
      _balance = null;
      _assetSummary = null;
      _buyPower = null;
      _periodProfitLoss = null;
      _error = null;
      _loading = false;
    }
  }

  Future<void> _fetch(String accountNo, String productCode, bool isPaper) async {
    if (_loading) return;
    setState(() => _loading = true);
    _error = null;
    try {
      final balance = await _repo!.getBalance(
        accountNo: accountNo,
        productCode: productCode,
      );
      AssetSummary? assetSummary;
      BuyPower? buyPower;
      PeriodProfitLoss? periodProfitLoss;

      if (!isPaper) {
        try {
          assetSummary = await _repo!.getAssetSummary(
            accountNo: accountNo,
            productCode: productCode,
          );
        } catch (_) {}
        try {
          buyPower = await _repo!.getBuyPower(
            accountNo: accountNo,
            productCode: productCode,
          );
        } catch (_) {}
        try {
          final today = DateTime.now();
          final start = today.subtract(const Duration(days: 30));
          periodProfitLoss = await _repo!.getPeriodProfitLoss(
            accountNo: accountNo,
            productCode: productCode,
            startDate: '${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}',
            endDate: '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}',
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _balance = balance;
          _assetSummary = assetSummary;
          _buyPower = buyPower;
          _periodProfitLoss = periodProfitLoss;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final env = isPaper ? '모의투자' : '실전투자';
        final acct = '$accountNo-$productCode';
        setState(() {
          if (msg.contains('OPSQ2000') || msg.contains('INVALID_CHECK_ACNO')) {
            _error = '[$env] 계좌번호($acct)가 유효하지 않습니다.\n'
                '앱키에 등록된 계좌인지 KIS Developers 포털에서 확인하거나, '
                'KIS 뱃지를 탭하여 계좌번호를 다시 입력해보세요.';
          } else {
            _error = '$env 조회 실패: $msg';
          }
          _loading = false;
        });
      }
    }
  }

  Widget _welcomeCard(ColorScheme cs, bool connected, String envLabel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [cs.primaryContainer, cs.primary.withValues(alpha: 0.6)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('대시보드', style: poppins(fontSize: 24, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
        const SizedBox(height: 4),
        Text(
          connected ? '$envLabel 연결됨 · ${_balance?.holdings.length ?? 0}종목 보유' : 'KIS 연결 후 이용 가능',
          style: inter(fontSize: 13, color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
        ),
      ]),
    );
  }

  Widget _assetCards(ColorScheme cs) {
    final b = _balance!;
    final a = _assetSummary;
    final p = _periodProfitLoss;
    final bp = _buyPower;
    final profitColor = b.evaluationProfitLoss >= 0 ? Colors.red : Colors.blue;
    final profitSign = b.evaluationProfitLoss >= 0 ? '+' : '';

    return Column(children: [
      Row(children: [
        Expanded(child: _statCard(cs, '총자산', _fmt(b.totalAsset), Icons.account_balance_wallet_rounded, large: true)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(cs, '예수금', _fmt(b.deposit), Icons.savings_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(cs, 'D+1 예수금', _fmt(b.d1Deposit), Icons.schedule_rounded)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _statCard(cs, '주식평가', _fmt(b.stockEvaluation), Icons.show_chart_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(
          cs, '평가손익', '$profitSign${_fmt(b.evaluationProfitLoss)}',
          Icons.trending_up_rounded, valueColor: profitColor,
        )),
        const SizedBox(width: 12),
        Expanded(child: _statCard(
          cs, '수익률', '$profitSign${b.evaluationProfitRate.toStringAsFixed(2)}%',
          Icons.percent_rounded, valueColor: profitColor,
        )),
      ]),
      if (a != null || bp != null || p != null) ...[
        const SizedBox(height: 8),
        Row(children: [
          if (a != null)
            Expanded(child: _statCard(cs, '프레젠트금액', _fmt(a.presentAmount), Icons.monetization_on_rounded)),
          if (a != null && bp != null) const SizedBox(width: 12),
          if (bp != null)
            Expanded(child: _statCard(cs, '매수가능금액', _fmt(bp.maxOrderAmount), Icons.shopping_cart_rounded)),
          if (bp != null && p != null) const SizedBox(width: 12),
          if (p != null)
            Expanded(child: _statCard(cs, '최근 30일 손익', _fmt(p.profitLossAmount), Icons.date_range_rounded)),
        ]),
      ],
    ]);
  }

  Widget _holdingsTable(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('보유 종목', style: poppins(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 10),
        ..._balance!.holdings.map((h) => _holdingRow(cs, h)),
      ]),
    );
  }

  Widget _holdingRow(ColorScheme cs, StockHolding h) {
    final profitColor = h.profitLoss >= 0 ? Colors.red : Colors.blue;
    final sign = h.profitLoss >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.06)))),
      child: Row(children: [
        SizedBox(width: 80, child: Text(h.symbol, style: inter(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface))),
        Expanded(flex: 2, child: Text(h.name, style: inter(fontSize: 11, color: cs.onSurfaceVariant))),
        SizedBox(width: 60, child: Text('${h.quantity}주', style: inter(fontSize: 11, color: cs.onSurface), textAlign: TextAlign.right)),
        SizedBox(width: 80, child: Text(_fmt(h.avgPrice), style: inter(fontSize: 11, color: cs.onSurface), textAlign: TextAlign.right)),
        SizedBox(width: 80, child: Text(_fmt(h.evaluationAmount), style: inter(fontSize: 11, color: cs.onSurface), textAlign: TextAlign.right)),
        SizedBox(width: 70, child: Text('$sign${_fmt(h.profitLoss)}', style: inter(fontSize: 11, fontWeight: FontWeight.w600, color: profitColor), textAlign: TextAlign.right)),
        SizedBox(width: 60, child: Text('$sign${h.profitRate.toStringAsFixed(1)}%', style: inter(fontSize: 11, fontWeight: FontWeight.w600, color: profitColor), textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _statCard(ColorScheme cs, String label, String value, IconData icon, {bool large = false, Color? valueColor}) {
    return Container(
      padding: EdgeInsets.all(large ? 16 : 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: large ? 22 : 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: inter(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 6),
        Text(
          value,
          style: poppins(fontSize: large ? 24 : 18, fontWeight: FontWeight.w700, color: valueColor ?? cs.onSurface),
        ),
      ]),
    );
  }

  Widget _vwapPocRecommendationCard(ColorScheme cs, List<VwapPocItem> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.analytics_rounded, size: 18, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Text('VWAP+POC 추천 TOP 10', style: poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('vwap_poc 적합도 기준', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _vwapTh('순위', cs, flex: 1),
          _vwapTh('종목', cs, flex: 1),
          _vwapTh('종목명', cs, flex: 2),
          _vwapTh('점수', cs, flex: 1),
          _vwapTh('수익률', cs, flex: 1),
          _vwapTh('추세', cs, flex: 1),
        ]),
        const Divider(height: 1),
        SizedBox(
          height: (items.length * 26.0).clamp(0, 260),
          child: ListView.builder(
            itemCount: items.length,
            itemExtent: 26.0,
            itemBuilder: (_, i) {
              final item = items[i];
              final trend = item.vwapSlope > 0 ? '상승' : item.vwapSlope < 0 ? '하락' : '횡보';
              final rankColor = i < 3 ? Colors.orange : Colors.grey;
              final isGood = item.score >= 7;
              return Container(
                color: isGood ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
                child: Row(children: [
                  _vwapTd('${i + 1}', cs, flex: 1, color: rankColor, bold: i < 3),
                  _vwapTd(item.code, cs, flex: 1),
                  _vwapTd(item.name, cs, flex: 2),
                  _vwapTd('${item.score}/10', cs, flex: 1, color: isGood ? Colors.green : Colors.grey),
                  _vwapTd('${item.periodReturn >= 0 ? '+' : ''}${item.periodReturn.toStringAsFixed(1)}%', cs, flex: 1, color: item.periodReturn >= 0 ? Colors.red : Colors.blue),
                  _vwapTd(trend, cs, flex: 1, color: item.vwapSlope > 0 ? Colors.red : Colors.blue),
                ]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Icon(Icons.terminal_rounded, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('갱신: dart run bin/vwap_poc_screen.dart',
              style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }

  Widget _vwapTh(String label, ColorScheme cs, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _vwapTd(String text, ColorScheme cs, {int flex = 1, Color? color, bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: color ?? cs.onSurface),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '₩0';
    return v < 0
        ? '-₩${v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
        : '₩${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}
