import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/theme/font_helper.dart';

import '../../../features/backtest/data/datasources/kis_stock_api.dart';
import '../../../features/backtest/domain/entities/backtest_result.dart';
import '../../../features/backtest/presentation/bloc/backtest_bloc.dart';
import '../../../features/backtest/presentation/bloc/backtest_event.dart';
import '../../../features/backtest/presentation/bloc/backtest_state.dart';
import '../../../features/kis_auth/presentation/bloc/kis_auth_bloc.dart';
import '../../../features/kis_auth/presentation/bloc/kis_auth_state.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/stock_search_field.dart';

class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});
  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  final _symbolCtl = TextEditingController(text: '005930');
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isMinute = false;
  bool _useRsiFilter = false;
  bool _useAtrStop = false;
  bool _adaptiveMode = false;
  double _atrMultiplier = 2.0;
  double _rsiOversold = 30;
  double _rsiOverbought = 70;
  double _entryThresholdTicks = 10;
  double _takeProfitTicks = 20;
  double _stopLossTicks = 10;
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
    _bloc.close();
    super.dispose();
  }

  double get _tickSize {
    final s = _bloc.state;
    final candles = (s is BacktestDataLoaded) ? s.candles :
                    (s is BacktestCompleted) ? s.candles : null;
    if (candles == null || candles.isEmpty) return 100;
    final avgPrice = candles.map((c) => c.close).reduce((a, b) => a + b) / candles.length;
    if (avgPrice >= 100000) return 100;
    if (avgPrice >= 10000) return 50;
    if (avgPrice >= 5000) return 10;
    return 5;
  }

  KisStockApi? _buildApi() {
    final s = context.read<KisAuthBloc>().state;
    if (s is! KisAuthConnected) return null;
    final c = s.connection;
    final a = c.active;
    if (a == null) return null;
    return KisStockApi(appKey: a.appKey, appSecret: a.appSecret, isPaper: !c.useMock);
  }

  bool _canLoad() {
    final api = _buildApi();
    return api != null && !(_bloc.state is BacktestDataLoading || _bloc.state is BacktestRunning);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocProvider.value(
      value: _bloc,
      child: Builder(builder: (context) {
    final s = context.watch<BacktestBloc>().state;
    final loading = s is BacktestDataLoading || s is BacktestRunning;
    final candles = (s is BacktestDataLoaded) ? s.candles :
                    (s is BacktestRunning) ? s.candles :
                    (s is BacktestCompleted) ? s.candles : null;
    final result = (s is BacktestCompleted) ? s.result : null;
    final status = (s is BacktestDataLoading) ? s.status :
                   (s is BacktestRunning) ? s.status : '';

    return Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          children: [
            Text('백테스트', style: poppins(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('VWAP + POC 전략', style: inter(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),

            _card(cs, children: [
              StockSearchField(
                onSelected: (stock) {
                  _symbolCtl.text = stock.code;
                  _bloc.add(BacktestDeleteCache(
                    symbol: stock.code, startDate: _startDate, endDate: _endDate,
                    tickSize: _tickSize,
                  ));
                },
                initialCode: _symbolCtl.text,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('시작', style: inter(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                        style: inter(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Text('종료', style: inter(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text('${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                        style: inter(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Text('${_endDate.difference(_startDate).inDays ~/ 30}개월',
                      style: inter(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('일', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: true, label: Text('분', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_isMinute},
                    onSelectionChanged: (v) => setState(() => _isMinute = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _canLoad() ? _load : null,
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 18),
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
                  const SizedBox(width: 12),
                  Text('진입', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  SizedBox(width: 50, child: Slider(
                    value: _entryThresholdTicks, min: 0, max: 30, divisions: 6,
                    label: '${_entryThresholdTicks.toStringAsFixed(0)}틱',
                    onChanged: (v) => setState(() => _entryThresholdTicks = v),
                  )),
                  Text('${_entryThresholdTicks.toStringAsFixed(0)}틱', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Text('익절', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  SizedBox(width: 50, child: Slider(
                    value: _takeProfitTicks, min: 0, max: 50, divisions: 10,
                    label: '${_takeProfitTicks.toStringAsFixed(0)}틱',
                    onChanged: (v) => setState(() => _takeProfitTicks = v),
                  )),
                  Text('${_takeProfitTicks.toStringAsFixed(0)}틱', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Text('손절', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  SizedBox(width: 50, child: Slider(
                    value: _stopLossTicks, min: 0, max: 30, divisions: 6,
                    label: '${_stopLossTicks.toStringAsFixed(0)}틱',
                    onChanged: (v) => setState(() => _stopLossTicks = v),
                  )),
                  Text('${_stopLossTicks.toStringAsFixed(0)}틱', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  if (!_adaptiveMode) ...[
                    _filterChip('RSI 필터', _useRsiFilter, Colors.blue, (v) => setState(() => _useRsiFilter = v)),
                    if (_useRsiFilter) ...[
                      const SizedBox(width: 8),
                      Text('과매수', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      SizedBox(width: 60, child: Slider(
                        value: _rsiOverbought, min: 50, max: 95, divisions: 9,
                        label: _rsiOverbought.toStringAsFixed(0),
                        onChanged: (v) => setState(() => _rsiOverbought = v),
                      )),
                      Text('${_rsiOverbought.toStringAsFixed(0)}', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Text('과매도', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      SizedBox(width: 60, child: Slider(
                        value: _rsiOversold, min: 5, max: 50, divisions: 9,
                        label: _rsiOversold.toStringAsFixed(0),
                        onChanged: (v) => setState(() => _rsiOversold = v),
                      )),
                      Text('${_rsiOversold.toStringAsFixed(0)}', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                    ],
                    _filterChip('ATR 손절', _useAtrStop, Colors.orange, (v) => setState(() => _useAtrStop = v)),
                    if (_useAtrStop) ...[
                      const SizedBox(width: 8),
                      Text('ATR×', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      SizedBox(width: 60, child: Slider(
                        value: _atrMultiplier, min: 0.5, max: 5, divisions: 9,
                        label: _atrMultiplier.toStringAsFixed(1),
                        onChanged: (v) => setState(() => _atrMultiplier = v),
                      )),
                      Text('${_atrMultiplier.toStringAsFixed(1)}', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                    ],
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
                    _stat('캔들', '${candles.length}'),
                    const SizedBox(width: 24),
                    _stat('시작', candles.first.timestamp.toLocal().toString().substring(0, 10)),
                    const SizedBox(width: 24),
                    _stat('종료', candles.last.timestamp.toLocal().toString().substring(0, 10)),
                    const SizedBox(width: 24),
                    _stat('간격', _isMinute ? '분봉' : '일봉'),
                    const SizedBox(width: 24),
                    OutlinedButton.icon(
                      onPressed: () => _bloc.add(BacktestDeleteCache(
                        symbol: _symbolCtl.text.trim(), startDate: _startDate,
                        endDate: _endDate, tickSize: _tickSize,
                      )),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('캐시 삭제', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade300, side: BorderSide(color: Colors.red.shade300)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: (candles.isNotEmpty && !loading) ? _run : null,
                      icon: s is BacktestRunning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(s is BacktestRunning ? '실행 중...' : '백테스트 실행'),
                    ),
                  ]),
                ),
              ]),
            ],

            if (result != null) ...[
              const SizedBox(height: 12),
              _card(cs, title: '백테스트 결과', children: [
                _resultRow(cs, result),
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

  void _load() {
    final api = _buildApi();
    if (api == null) return;
    final symbol = _symbolCtl.text.trim();
    if (symbol.isEmpty) return;
    _bloc.add(BacktestLoadData(
      symbol: symbol, startDate: _startDate, endDate: _endDate,
      isMinute: _isMinute, appKey: api.appKey, appSecret: api.appSecret, isPaper: api.isPaper,
    ));
  }

  void _run() {
    if (_bloc.state is! BacktestDataLoaded && _bloc.state is! BacktestCompleted) return;
    _bloc.add(BacktestRun(
      tickSize: _tickSize,
      adaptiveMode: _adaptiveMode,
      entryThresholdTicks: _entryThresholdTicks,
      takeProfitTicks: _takeProfitTicks,
      stopLossTicks: _stopLossTicks,
      stopLossPercent: _useAtrStop ? 0 : 5,
      useAtrStop: _adaptiveMode ? true : _useAtrStop, atrMultiplier: _atrMultiplier,
      useRsiFilter: _adaptiveMode ? true : _useRsiFilter,
      rsiOversold: _rsiOversold, rsiOverbought: _rsiOverbought,
      mode: 'vwap_cross', commissionPercent: 0.147, symbol: _symbolCtl.text.trim(),
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

  Widget _resultRow(ColorScheme cs, BacktestResult r) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _rStat('순손익', r.netReturn.toStringAsFixed(0), r.netReturn >= 0 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('수수료', '${r.totalCommission.toStringAsFixed(0)}원 (0.147%)', Colors.grey),
        const SizedBox(width: 20),
        _rStat('총손익(수수료전)', r.totalReturn.toStringAsFixed(0), r.totalReturn >= 0 ? Colors.green : Colors.red),
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
      Row(children: [
        _th('진입', cs), _th('청산', cs), _th('방향', cs), _th('PnL', cs),
      ]),
      SizedBox(
        height: 200,
        child: ListView.builder(
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
        ),
      ),
    ]);
  }

  Widget _th(String label, ColorScheme cs) => SizedBox(
    width: 100, child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
    ),
  );

  Widget _td(String text, {bool bold = false, Color? color}) => SizedBox(
    width: 100, child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
    ),
  );

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
          Text(label, style: inter(fontSize: 11, fontWeight: FontWeight.w600,
              color: value ? color : color.withValues(alpha: 0.6))),
          const SizedBox(width: 4),
          Icon(value ? Icons.check_rounded : Icons.add_rounded, size: 12,
              color: value ? color : color.withValues(alpha: 0.5)),
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
