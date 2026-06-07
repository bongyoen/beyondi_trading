import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/backtest/data/datasources/kis_stock_api.dart';
import '../../../features/backtest/domain/entities/backtest_result.dart';
import '../../../features/backtest/domain/entities/stock_suitability.dart';
import '../../../features/backtest/presentation/bloc/backtest_bloc.dart';
import '../../../features/backtest/presentation/bloc/backtest_event.dart';
import '../../../features/backtest/presentation/bloc/backtest_state.dart';
import '../../../features/kis_auth/presentation/bloc/kis_auth_bloc.dart';
import '../../../features/kis_auth/presentation/bloc/kis_auth_state.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/font_helper.dart';
import '../../../shared/widgets/stock_search_field.dart';

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
  bool _isMinute = true;
  bool _useRsiFilter = true;
  bool _useAtrStop = false;
  bool _adaptiveMode = false;
  double _atrMultiplier = 2.0;
  double _rsiOversold = 30;
  double _rsiOverbought = 70;
  double _entryThresholdTicks = 15;
  double _takeProfitTicks = 0;
  double _stopLossTicks = 0;
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

  void _applyOptimal() {
    final s = _suitable;
    if (s == null || !s.isProfitable) return;
    setState(() {
      _useRsiFilter = s.code == '005930' || s.code == '012330' || s.code == '028260';
      _entryThresholdTicks = s.code == '005930' ? 15 : 0;
      _takeProfitTicks = 0;
      _stopLossTicks = 0;
      _rsiOverbought = s.code == '028260' ? 65 : 70;
      _rsiOversold = s.code == '028260' ? 35 : 30;
    });
  }

  KisStockApi? _buildApi() {
    final st = context.read<KisAuthBloc>().state;
    if (st is! KisAuthConnected) return null;
    final c = st.connection;
    final a = c.active;
    if (a == null) return null;
    return KisStockApi(appKey: a.appKey, appSecret: a.appSecret, isPaper: !c.useMock);
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
      isMinute: _isMinute, appKey: api.appKey, appSecret: api.appSecret, isPaper: api.isPaper,
    ));
  }

  void _run() {
    if (_bloc.state is! BacktestDataLoaded && _bloc.state is! BacktestCompleted) return;
    _bloc.add(BacktestRun(
      tickSize: _tickSize, adaptiveMode: _adaptiveMode,
      entryThresholdTicks: _entryThresholdTicks, takeProfitTicks: _takeProfitTicks, stopLossTicks: _stopLossTicks,
      stopLossPercent: _useAtrStop ? 0 : 5,
      useAtrStop: _adaptiveMode ? true : _useAtrStop, atrMultiplier: _atrMultiplier,
      useRsiFilter: _adaptiveMode ? true : _useRsiFilter,
      rsiOversold: _rsiOversold, rsiOverbought: _rsiOverbought,
      mode: 'hybrid', commissionPercent: 0.147,
      principal: double.tryParse(_principalCtl.text) ?? 0,
      symbol: _symbolCtl.text.trim(),
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
              Text('VWAP Cross  ·  수수료 0.147%', style: inter(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),

              _card(cs, children: [
                Row(children: [
                  Expanded(child: StockSearchField(
                    onSelected: (stock) {
                      _symbolCtl.text = stock.code;
                      _applyOptimal();
                      _bloc.add(BacktestDeleteCache(
                        symbol: stock.code, startDate: _startDate, endDate: _endDate, tickSize: _tickSize,
                      ));
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
                    if (suit.isProfitable) ...[
                      const SizedBox(width: 4),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _applyOptimal,
                        child: Text('권장설정', style: inter(fontSize: 10)),
                      ),
                    ],
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
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('분', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: false, label: Text('일', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_isMinute},
                      onSelectionChanged: (v) => setState(() => _isMinute = v.first),
                      style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: WidgetStatePropertyAll(EdgeInsets.zero)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _canLoad() ? _load : null,
                      icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                      label: Text(loading ? '로딩 중...' : '데이터 로드'),
                    ),
                  ]),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(status, style: inter(fontSize: 13, color: status.startsWith('오류') ? Colors.red : Colors.grey)),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _filterChip('Adaptive', _adaptiveMode, Colors.purple, (v) => setState(() => _adaptiveMode = v)),
                    if (!_adaptiveMode) ...[
                      const SizedBox(width: 12),
                      _miniSlider('진입', _entryThresholdTicks, 0, 30, 6, (v) => _entryThresholdTicks = v),
                      _miniSlider('익절', _takeProfitTicks, 0, 50, 10, (v) => _takeProfitTicks = v),
                      _miniSlider('손절', _stopLossTicks, 0, 30, 6, (v) => _stopLossTicks = v),
                      const SizedBox(width: 12),
                      _filterChip('RSI', _useRsiFilter, Colors.blue, (v) => setState(() => _useRsiFilter = v)),
                      if (_useRsiFilter) ...[
                        const SizedBox(width: 8),
                        _miniSlider('과매수', _rsiOverbought, 50, 95, 9, (v) => _rsiOverbought = v),
                        _miniSlider('과매도', _rsiOversold, 5, 50, 9, (v) => _rsiOversold = v),
                      ],
                      const SizedBox(width: 8),
                      _filterChip('ATR', _useAtrStop, Colors.orange, (v) => setState(() => _useAtrStop = v)),
                      if (_useAtrStop) _miniSlider('ATR×', _atrMultiplier, 0.5, 5, 9, (v) => _atrMultiplier = v),
                    ],
                  ]),
                ),
              ]),

              if (candles != null && candles.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(cs, title: '데이터 현황', children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _stat('캔들', '${candles.length}'), const SizedBox(width: 24),
                      _stat('시작', candles.first.timestamp.toLocal().toString().substring(0, 10)), const SizedBox(width: 24),
                      _stat('종료', candles.last.timestamp.toLocal().toString().substring(0, 10)), const SizedBox(width: 24),
                      _stat('간격', _isMinute ? '분봉' : '일봉'), const SizedBox(width: 24),
                      OutlinedButton.icon(
                        onPressed: () => _bloc.add(BacktestDeleteCache(
                          symbol: _symbolCtl.text.trim(), startDate: _startDate, endDate: _endDate, tickSize: _tickSize,
                        )),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('캐시 삭제', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade300, side: BorderSide(color: Colors.red.shade300)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: (candles.isNotEmpty && !loading) ? _run : null,
                        icon: st is BacktestRunning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(st is BacktestRunning ? '실행 중...' : '백테스트 실행'),
                      ),
                    ]),
                  ),
                ]),
              ],

              if (result != null) ...[
                const SizedBox(height: 12),
                _card(cs, title: '백테스트 결과', children: [
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
                ]),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _miniSlider(String label, double value, double min, double max, int div, void Function(double) onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: inter(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      SizedBox(width: 50, child: Slider(value: value, min: min, max: max, divisions: div, label: value.toStringAsFixed(max > 30 ? 1 : 0), onChanged: (v) => setState(() => onChanged(v)))),
      Text(value.toStringAsFixed(max > 30 ? 1 : 0), style: inter(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
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
      Row(children: [_th('진입', cs), _th('청산', cs), _th('방향', cs), _th('PnL', cs)]),
      SizedBox(height: 200, child: ListView.builder(
        itemCount: r.trades.length,
        itemExtent: 28,
        itemBuilder: (_, i) {
          final t = r.trades[i];
          final win = t.pnl > 0;
          return Container(
            color: win ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
            child: Row(children: [
              _td(t.entryTime.toString().substring(0, 10)),
              _td(t.exitTime.toString().substring(0, 10)),
              _td(t.signal.name == 'strongBuy' ? 'Long' : 'Short', color: win ? Colors.green : Colors.red),
              _td(t.pnl.toStringAsFixed(0), bold: true, color: win ? Colors.green : Colors.red),
            ]),
          );
        },
      )),
    ]);
  }

  Widget _th(String label, ColorScheme cs) => SizedBox(width: 100, child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
  ));
  Widget _td(String text, {bool bold = false, Color? color}) => SizedBox(width: 100, child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
  ));
  Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: poppins(fontSize: 15, fontWeight: FontWeight.w600)),
    Text(label, style: inter(fontSize: 11, color: Colors.grey)),
  ]);
  Widget _rStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    Text(label, style: inter(fontSize: 10, color: Colors.grey)),
  ]);

  Widget _filterChip(String label, bool value, Color color, void Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: value ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: inter(fontSize: 11, fontWeight: FontWeight.w600, color: value ? color : color.withValues(alpha: 0.6))),
          const SizedBox(width: 4),
          Icon(value ? Icons.check_rounded : Icons.add_rounded, size: 12, color: value ? color : color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _card(ColorScheme cs, {String? title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Icon(Icons.analytics_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(title, style: poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
        ],
        ...children,
      ]),
    );
  }
}
