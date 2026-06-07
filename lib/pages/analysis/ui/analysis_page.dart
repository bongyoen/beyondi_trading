import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/features/kis_account/api/kis_account_repository.dart';
import 'package:beyondi_trading/entities/period_profit_loss/model/period_profit_loss.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_state.dart';
import 'package:beyondi_trading/shared/constants/app_constants.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';
import 'package:beyondi_trading/shared/ui/app_card.dart';
import 'package:beyondi_trading/shared/ui/table_row.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  List<BatchEntry> _batchResults = [];
  PeriodProfitLoss? _periodPnl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBatchResults();
  }

  Future<void> _loadBatchResults() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/batch_results_longonly.json');
      if (await file.exists()) {
        final text = await file.readAsString();
        final data = jsonDecode(text) as List<dynamic>;
        setState(() {
          _batchResults = data.map((e) => BatchEntry.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {}
  }

  void _fetchPeriodPnl(KisStockApi api, String accountNo, String productCode) async {
    setState(() => _loading = true);
    try {
      final repo = KisAccountRepository(api: api);
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 365));
      final pnl = await repo.getPeriodProfitLoss(
        accountNo: accountNo,
        productCode: productCode,
        startDate: '${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}',
        endDate: '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
      );
      if (mounted) setState(() => _periodPnl = pnl);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authState = context.watch<KisAuthBloc>().state;
    final connected = authState is KisAuthConnected && authState.connection.isTokenValid;

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        children: [
          Text('분석', style: poppins(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('성과 분석 및 리스크 메트릭', style: inter(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),

          if (connected && _periodPnl == null && !_loading) ...[
            AppCard(cs: cs, title: 'KIS 기간 손익', children: [
              ElevatedButton.icon(
                onPressed: connected
                    ? () {
                        final c = authState.connection;
                        final a = c.active;
                        if (a != null) {
                          _fetchPeriodPnl(
                            KisStockApi(appKey: a.appKey, appSecret: a.appSecret, isPaper: c.useMock),
                            a.accountNo!,
                            a.productCode ?? '01',
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('KIS 손익 데이터 로드'),
              ),
            ]),
          ],
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          if (_error != null) _errorCard(cs, _error!),

          if (_periodPnl != null)
            AppCard(cs: cs, title: 'KIS 기간 손익', children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _stat('총매수', '₩${_fmt(_periodPnl!.totalBuyAmount)}'),
                  _stat('총매도', '₩${_fmt(_periodPnl!.totalSellAmount)}'),
                  _stat('손익', '₩${_fmt(_periodPnl!.profitLossAmount)}', color: _periodPnl!.profitLossAmount >= 0 ? Colors.red : Colors.blue),
                  _stat('수익률', '${_periodPnl!.profitLossRate.toStringAsFixed(2)}%', color: _periodPnl!.profitLossRate >= 0 ? Colors.red : Colors.blue),
                ]),
              ),
            ]),

          if (_batchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(cs: cs, title: '배치 테스트 요약 (${_batchResults.length}종목)', children: [
              _batchSummary(cs),
            ]),
            const SizedBox(height: 12),
            AppCard(cs: cs, title: '수익률 분포', children: [
              SizedBox(height: 200, child: _batchDistributionChart(cs)),
            ]),
            const SizedBox(height: 12),
            AppCard(cs: cs, title: '종목별 성과', children: [
              _batchTable(cs),
            ]),
          ],

          if (_batchResults.isEmpty && _periodPnl == null && !_loading) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(children: [
                Icon(Icons.analytics_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('분석 데이터 없음', style: poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey.withValues(alpha: 0.5))),
                const SizedBox(height: 4),
                Text('백테스트 실행 또는 KIS 계정 연결 후 조회하세요', style: inter(fontSize: 13, color: Colors.grey.withValues(alpha: 0.4))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _batchSummary(ColorScheme cs) {
    final profitable = _batchResults.where((b) => b.netReturn > 0).length;
    final totalReturn = _batchResults.fold(0.0, (s, b) => s + b.netReturn);
    final avgWinRate = _batchResults.isEmpty ? 0 : _batchResults.map((b) => b.winRate).reduce((a, b) => a + b) / _batchResults.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _stat('수익종목', '$profitable/${_batchResults.length}', color: Colors.green),
        _stat('총순손익', '₩${_fmt(totalReturn)}', color: totalReturn >= 0 ? Colors.red : Colors.blue),
        _stat('평균승률', '${(avgWinRate * 100).toStringAsFixed(1)}%'),
      ]),
    );
  }

  Widget _batchDistributionChart(ColorScheme cs) {
    final returns = _batchResults.map((b) => b.netReturn).toList();
    if (returns.isEmpty) return const SizedBox();
    final maxR = returns.map((r) => r.abs()).reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        barGroups: returns.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: e.value > 0 ? Colors.red : Colors.blue,
              width: maxR > 100000 ? 3 : 6,
            ),
          ],
        )).toList(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxR / 4,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('₩${_fmt(v)}', style: const TextStyle(fontSize: 8)))),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _batchTable(ColorScheme cs) {
    final sorted = List<BatchEntry>.from(_batchResults)
      ..sort((a, b) => b.netReturn.compareTo(a.netReturn));
    return Column(children: [
      Row(children: [
        Th('종목', cs, flex: 1),
        Th('순손익', cs, flex: 2),
        Th('승률', cs, flex: 1),
        Th('거래', cs, flex: 1),
        Th('MDD', cs, flex: 1),
      ]),
      SizedBox(
        height: (sorted.length * 24.0).clamp(0, 300),
        child: ListView.builder(
          itemCount: sorted.length,
          itemExtent: 24.0,
          itemBuilder: (_, i) {
            final b = sorted[i];
            return Container(
              color: b.netReturn > 0 ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.03),
              child: Row(children: [
                Td(b.symbol, flex: 1),
                Td('₩${_fmt(b.netReturn)}', flex: 2, color: b.netReturn >= 0 ? Colors.red : Colors.blue),
                Td('${(b.winRate * 100).toStringAsFixed(0)}%', flex: 1),
                Td('${b.trades}', flex: 1),
                Td(b.maxDrawdown.toStringAsFixed(0), flex: 1),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _errorCard(ColorScheme cs, String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
        child: Row(children: [Icon(Icons.error_rounded, size: 16, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(error, style: inter(fontSize: 11, color: Colors.red.shade800)))]),
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: poppins(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: inter(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    return v < 0 ? '-₩${v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}' : '₩${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

class BatchEntry {
  final String symbol;
  final double netReturn;
  final double winRate;
  final int trades;
  final double maxDrawdown;

  const BatchEntry({
    required this.symbol,
    required this.netReturn,
    required this.winRate,
    required this.trades,
    required this.maxDrawdown,
  });

  factory BatchEntry.fromJson(Map<String, dynamic> json) {
    return BatchEntry(
      symbol: json['symbol'] as String? ?? '',
      netReturn: (json['netReturn'] as num?)?.toDouble() ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      trades: (json['trades'] as num?)?.toInt() ?? 0,
      maxDrawdown: (json['maxDrawdown'] as num?)?.toDouble() ?? 0,
    );
  }
}
