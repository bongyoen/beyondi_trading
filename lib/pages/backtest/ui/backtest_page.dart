import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/entities/backtest_result/model/backtest_result.dart';
import 'package:beyondi_trading/entities/stock_suitability/model/stock_suitability.dart';
import 'package:beyondi_trading/features/backtest/bloc/backtest_bloc.dart';
import 'package:beyondi_trading/features/backtest/bloc/backtest_event.dart';
import 'package:beyondi_trading/features/backtest/bloc/backtest_state.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_state.dart';
import 'package:beyondi_trading/shared/constants/app_constants.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';
import 'package:beyondi_trading/shared/ui/app_card.dart';
import 'package:beyondi_trading/shared/ui/table_row.dart';
import 'package:beyondi_trading/widgets/stock_search/ui/stock_search_field.dart';

class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});
  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  final _symbolCtl = TextEditingController(text: '005930');
  final _principalCtl = TextEditingController(text: '10000000');
  late DateTime _startDate;
  late DateTime _endDate;
  late final BacktestBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = BacktestBloc();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year - 1, _endDate.month, _endDate.day);
  }

  @override
  void dispose() {
    _symbolCtl.dispose();
    _principalCtl.dispose();
    _bloc.close();
    super.dispose();
  }

  StockSuitability? get _suitable => StockSuitability.known[_symbolCtl.text.trim()];

  double get _tickSize {
    final st = _bloc.state;
    final c = (st is BacktestDataLoaded) ? st.candles : (st is BacktestCompleted) ? st.candles : null;
    if (c == null || c.isEmpty) return 100;
    final avg = c.map((x) => x.close).reduce((a, b) => a + b) / c.length;
    if (avg >= 100000) return 100;
    if (avg >= 10000) return 50;
    if (avg >= 5000) return 10;
    return 5;
  }

  KisStockApi? _buildApi() {
    final st = context.read<KisAuthBloc>().state;
    if (st is! KisAuthConnected) return null;
    final c = st.connection;
    final a = c.active;
    if (a == null) return null;
    return KisStockApi(appKey: a.appKey, appSecret: a.appSecret, isPaper: c.useMock);
  }

  bool _canLoad() {
    final api = _buildApi();
    return api != null && !(_bloc.state is BacktestDataLoading || _bloc.state is BacktestRunning);
  }

  void _load() {
    final api = _buildApi();
    if (api == null) return;
    final sym = _symbolCtl.text.trim();
    if (sym.isEmpty) return;
    _bloc.add(BacktestLoadData(
      symbol: sym, startDate: _startDate, endDate: _endDate,
      isMinute: true, appKey: api.appKey, appSecret: api.appSecret, isPaper: api.isPaper,
    ));
  }

  void _run() {
    if (_bloc.state is! BacktestDataLoaded && _bloc.state is! BacktestCompleted) return;
    final principal = double.tryParse(_principalCtl.text) ?? 0;
    _bloc.add(BacktestRun(
      tickSize: _tickSize, adaptiveMode: false,
      entryThresholdTicks: 0, takeProfitTicks: 0, stopLossTicks: 0,
      stopLossPercent: 5, useAtrStop: false, atrMultiplier: 2.0,
      useRsiFilter: true, rsiOversold: 30, rsiOverbought: 70,
      mode: 'vwap_poc', commissionPercent: 0.147,
      principal: principal,
      symbol: _symbolCtl.text.trim(),
      consecutiveLossLimit: 10,
      dailyLossLimit: (principal * 0.1).clamp(30000, 1000000),
      maxTotalLoss: (principal * 0.3).clamp(50000, 5000000),
      useAtrPositionSizing: true,
      longOnly: true,
    ));
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(2000), lastDate: DateTime.now(),
    );
    if (picked != null) setState(() {
      if (isStart) _startDate = picked; else _endDate = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocProvider.value(
      value: _bloc,
      child: Builder(builder: (ctx) {
        final st = ctx.watch<BacktestBloc>().state;
        final loading = st is BacktestDataLoading || st is BacktestRunning;
        final candles = (st is BacktestDataLoaded) ? st.candles :
                       (st is BacktestRunning) ? st.candles :
                       (st is BacktestCompleted) ? st.candles : null;
        final result = (st is BacktestCompleted) ? st.result : null;
        final status = (st is BacktestDataLoading) ? st.status :
                      (st is BacktestRunning) ? st.status : '';
        final suit = _suitable;

        return Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            children: [
              Text('백테스트', style: poppins(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('VWAP+POC 반전 전략  ·  수수료 0.147%', style: inter(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),

              AppCard(cs: cs, children: [
                Row(children: [
                  Expanded(child: StockSearchField(
                    onSelected: (stock) {
                      setState(() {
                        _symbolCtl.text = stock.code;
                      });
                    },
                    initialCode: _symbolCtl.text,
                  )),
                  if (suit != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: (suit.isProfitable ? Colors.green : Colors.red).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(suit.returnLabel,
                        style: inter(fontSize: 11, fontWeight: FontWeight.w600,
                          color: suit.isProfitable ? Colors.green : Colors.red)),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('시작', style: inter(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}', style: inter(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Text('종료', style: inter(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text('${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}', style: inter(fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Text('${_endDate.difference(_startDate).inDays ~/ 30}개월', style: inter(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: TextField(
                      controller: _principalCtl,
                      decoration: const InputDecoration(
                        labelText: '원금', hintText: '10000000',
                        border: OutlineInputBorder(), isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 11),
                    )),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _canLoad() ? _load : null,
                      icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                      label: Text(loading ? '로딩 중...' : '데이터 로드'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: (candles != null && candles.isNotEmpty && !loading) ? _run : null,
                      icon: st is BacktestRunning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(st is BacktestRunning ? '실행 중...' : '백테스트 실행'),
                    ),
                  ]),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(status, style: inter(fontSize: 13, color: status.startsWith('오류') ? Colors.red : Colors.grey)),
                ],
              ]),

              if (result != null) ...[
                const SizedBox(height: 12),
                AppCard(cs: cs, title: '백테스트 결과', children: [
                  _resultRow(cs, result),
                  if (suit != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                      child: Text('이전 최적 결과: ${suit.returnLabel} / ${(suit.minuteWinRate * 100).toStringAsFixed(1)}% 승률 (${suit.bestConfig})', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (result.trades.isNotEmpty) _tradesTable(result, cs),
                  if (result.trades.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _chartRow(cs, result),
                  ],
                ]),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _chartRow(ColorScheme cs, BacktestResult r) {
    return Column(children: [
      Row(children: [
        Expanded(child: _equityChart(cs, r)),
        const SizedBox(width: 12),
        Expanded(child: _mddChart(cs, r)),
      ]),
      const SizedBox(height: 8),
      SizedBox(height: 80, child: _pnlDistribution(cs, r)),
    ]);
  }

  Widget _equityChart(ColorScheme cs, BacktestResult r) {
    final data = r.equityCurve;
    if (data.isEmpty) return const SizedBox();
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final minY = data.reduce((a, b) => a < b ? a : b);
    final range = (maxY - minY).abs().clamp(1, double.infinity);
    final padding = range * 0.1;
    return Container(
      height: 160, padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Equity Curve', style: inter(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Expanded(child: LineChart(LineChartData(
          minY: minY - padding, maxY: maxY + padding,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: range / 4),
          titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true, color: Colors.blue, barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
            ),
          ],
        ))),
      ]),
    );
  }

  Widget _mddChart(ColorScheme cs, BacktestResult r) {
    final data = r.equityCurve;
    if (data.isEmpty) return const SizedBox();
    double peak = 0;
    final ddSeries = data.map((v) {
      if (v > peak) peak = v;
      return peak > 0 ? (v - peak) / peak * 100 : 0.0;
    }).toList();
    final minDD = ddSeries.reduce((a, b) => a < b ? a : b);
    return Container(
      height: 160, padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MDD ${minDD.toStringAsFixed(1)}%', style: inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red)),
        const SizedBox(height: 4),
        Expanded(child: LineChart(LineChartData(
          minY: minDD * 1.2, maxY: 2,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: ddSeries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true, color: Colors.red, barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.1)),
            ),
          ],
        ))),
      ]),
    );
  }

  Widget _pnlDistribution(ColorScheme cs, BacktestResult r) {
    final pnls = r.trades.map((t) => t.pnl).toList();
    if (pnls.isEmpty) return const SizedBox();
    final wins = pnls.where((p) => p > 0).length;
    final losses = pnls.where((p) => p <= 0).length;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('거래별 손익 분포 (승:$wins 패:$losses)', style: inter(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Expanded(child: BarChart(BarChartData(
          alignment: BarChartAlignment.center,
          barGroups: pnls.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: e.value, color: e.value > 0 ? Colors.red : Colors.blue, width: 2),
          ])).toList(),
          gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ))),
      ]),
    );
  }

  Widget _resultRow(ColorScheme cs, BacktestResult r) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _rStat('순손익', r.netReturn.toStringAsFixed(0), r.netReturn >= 0 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('수익률', '${r.roi.toStringAsFixed(1)}%', r.roi >= 0 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('수수료', '${r.totalCommission.toStringAsFixed(0)}원 (0.147%)', Colors.grey),
        const SizedBox(width: 20),
        _rStat('승률', '${(r.winRate * 100).toStringAsFixed(1)}%', r.winRate >= 0.5 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('거래', '${r.totalSignals}회', Colors.blue),
        const SizedBox(width: 20),
        _rStat('Max DD', r.maxDrawdown.toStringAsFixed(1), Colors.orange),
        const SizedBox(width: 20),
        _rStat('Sharpe', r.sharpeRatio.toStringAsFixed(2), r.sharpeRatio >= 1 ? Colors.green : Colors.grey),
      ]),
    );
  }

  Widget _tradesTable(BacktestResult r, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [ThFixed('진입', cs), ThFixed('청산', cs), ThFixed('방향', cs), ThFixed('PnL', cs)]),
      SizedBox(height: 200, child: ListView.builder(
        itemCount: r.trades.length,
        itemExtent: 28,
        itemBuilder: (_, i) {
          final t = r.trades[i];
          final win = t.pnl > 0;
          return Container(
            color: win ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
            child: Row(children: [
              TdFixed(t.entryTime.toString().substring(0, 10)),
              TdFixed(t.exitTime.toString().substring(0, 10)),
              TdFixed(t.signal.name == 'strongBuy' ? 'Long' : 'Short', color: win ? Colors.green : Colors.red),
              TdFixed(t.pnl.toStringAsFixed(0), bold: true, color: win ? Colors.green : Colors.red),
            ]),
          );
        },
      )),
    ]);
  }

  Widget _rStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    Text(label, style: inter(fontSize: 10, color: Colors.grey)),
  ]);
}
