import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../features/backtest/data/datasources/candle_cache.dart';
import '../../../features/backtest/data/datasources/kis_stock_api.dart';
import '../../../features/backtest/domain/entities/backtest_result.dart';
import '../../../features/backtest/domain/entities/candle.dart';
import '../../../features/backtest/domain/usecases/run_backtest.dart';
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
  final _tickCtl = TextEditingController(text: '100');
  final _cache = CandleCache();
  List<Candle>? _candles;
  BacktestResult? _result;
  String? _status;
  bool _loading = false;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isMinute = false;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year - 1, _endDate.month, _endDate.day);
  }

  @override
  void dispose() {
    _symbolCtl.dispose();
    _tickCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) { _startDate = picked; }
        else { _endDate = picked; }
      });
    }
  }

  KisStockApi? _buildApi() {
    final s = context.read<KisAuthBloc>().state;
    if (s is! KisAuthConnected) return null;
    final c = s.connection;
    return KisStockApi(appKey: c.appKey, appSecret: c.appSecret, isPaper: c.isPaper);
  }

  Future<void> _load() async {
    final api = _buildApi();
    if (api == null) {
      setState(() => _status = 'KIS가 연결되지 않았습니다.');
      return;
    }

    final symbol = _symbolCtl.text.trim();
    if (symbol.isEmpty) {
      setState(() => _status = '종목코드를 입력하세요.');
      return;
    }

    setState(() { _loading = true; _status = '캐시 확인 중...'; _candles = null; _result = null; });

    try {
      final start = _startDate;
      final end = _endDate;

      final cached = await _cache.load(symbol: symbol, start: start, end: end);
      if (cached != null && cached.length > 50) {
        final ts = double.tryParse(_tickCtl.text) ?? 100;
        final saved = await _cache.loadResult(symbol: symbol, tickSize: ts);
        setState(() {
          _candles = cached;
          _result = saved;
          _loading = false;
          _status = '${cached.length}개 캔들 (캐시)';
        });
        return;
      }

      final all = <Candle>[];
      if (_isMinute) {
        final totalDays = end.difference(start).inDays + 1;
        final stream = _loadMinuteStream(api, symbol, start, end);
        int doneDays = 0;
        await for (final batch in stream) {
          all.addAll(batch);
          doneDays++;
          setState(() => _status = '분봉 로딩 중... $doneDays일/$totalDays일 (${all.length}캔들)');
        }
      } else {
        final stream = _loadDailyStream(api, symbol, start, end);
        await for (final batch in stream) {
          for (final c in batch) {
            if (!all.any((e) => e.timestamp == c.timestamp)) all.add(c);
          }
          setState(() => _status = '로딩 중... ${all.length}캔들');
        }
      }

      all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      await _cache.save(symbol: symbol, start: start, end: end, candles: all);
      setState(() { _candles = all; _loading = false; _status = '${all.length}개 캔들 로드 완료'; });
    } catch (e) {
      setState(() { _loading = false; _status = '오류: $e'; });
    }
  }

  /// 분봉 데이터를 날짜별로 스트리밍 로드.
  Stream<List<Candle>> _loadMinuteStream(KisStockApi api, String symbol, DateTime start, DateTime end) async* {
    final days = end.difference(start).inDays;
    for (int d = 0; d <= days; d++) {
      final date = start.add(Duration(days: d));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
      try {
        final chunk = await api.fetchMinuteCandles(symbol: symbol, date: date);
        if (chunk.isNotEmpty) yield chunk;
      } catch (_) {}
    }
  }

  /// 일봉 데이터를 100일 범위로 스트리밍 로드.
  Stream<List<Candle>> _loadDailyStream(KisStockApi api, String symbol, DateTime start, DateTime end) async* {
    DateTime cursor = end;
    while (true) {
      final from = cursor.subtract(const Duration(days: 100));
      final cs = from.isAfter(start) ? from : start;
      final chunk = await api.fetchDailyCandles(symbol: symbol, start: cs, end: cursor);
      if (chunk.isEmpty) break;
      yield chunk;
      if (cs == start) break;
      cursor = cs.subtract(const Duration(days: 1));
    }
  }

  Future<void> _deleteCache() async {
    final symbol = _symbolCtl.text.trim();
    final ts = double.tryParse(_tickCtl.text) ?? 100;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: Text('$symbol 데이터와 백테스트 결과를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await _cache.delete(symbol: symbol, start: _startDate, end: _endDate, tickSize: ts);
    setState(() { _candles = null; _result = null; _status = '캐시 삭제됨'; });
  }

  void _run() {
    if (_candles == null || _candles!.isEmpty) return;
    final ts = double.tryParse(_tickCtl.text) ?? 100;
    final symbol = _symbolCtl.text.trim();
    final result = runBacktest(
      candles: _candles!,
      tickSize: ts,
      stopLossPercent: 5,
      closeAtEndOfDay: true,
      mode: 'vwap_cross',
      commissionPercent: 0.05,
    );
    _cache.saveResult(symbol: symbol, tickSize: ts, result: result);
    setState(() { _result = result; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connected = context.watch<KisAuthBloc>().state is KisAuthConnected;

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        children: [
          Text('백테스트', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('VWAP + POC 전략', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),

          _card(cs, children: [
            StockSearchField(
              onSelected: (stock) {
                _symbolCtl.text = stock.code;
                _cache.delete(symbol: stock.code, start: _startDate, end: _endDate, tickSize: double.tryParse(_tickCtl.text) ?? 100);
                setState(() { _candles = null; _result = null; _status = '종목 변경: ${stock.display}'; });
              },
              initialCode: _symbolCtl.text,
            ),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(width: 100, child: TextField(
                controller: _tickCtl,
                decoration: const InputDecoration(labelText: 'Tick Size', border: OutlineInputBorder(), isDense: true),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text('시작', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text('종료', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text('${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 13)),
              ),
              const Spacer(),
              Text('${_endDate.difference(_startDate).inDays ~/ 30}개월',
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant)),
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
                onPressed: (connected && !_loading) ? _load : null,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_loading ? '로딩 중...' : '데이터 로드'),
              ),
            ]),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: GoogleFonts.inter(fontSize: 13, color: _status!.startsWith('오류') ? Colors.red : Colors.grey)),
            ],
          ]),

          if (_candles != null) ...[
            const SizedBox(height: 12),
            _card(cs, title: '데이터 현황', children: [
              Row(children: [
                _stat('캔들', '${_candles!.length}'),
                const SizedBox(width: 24),
                _stat('시작', _candles!.first.timestamp.toLocal().toString().substring(0, 10)),
                const SizedBox(width: 24),
                _stat('종료', _candles!.last.timestamp.toLocal().toString().substring(0, 10)),
                const SizedBox(width: 24),
                _stat('간격', _isMinute ? '분봉' : '일봉'),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _deleteCache(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('캐시 삭제', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade300, side: BorderSide(color: Colors.red.shade300)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _candles!.isNotEmpty ? _run : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('백테스트 실행'),
                ),
              ]),
            ]),
          ],

          if (_result != null) ...[
            const SizedBox(height: 12),
            _card(cs, title: '백테스트 결과', children: [
              _resultRow(cs),
              const SizedBox(height: 8),
              if (_result!.trades.isNotEmpty) _tradesTable(),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(ColorScheme cs) {
    final r = _result!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _rStat('순손익', r.netReturn.toStringAsFixed(0), r.netReturn >= 0 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('수수료', r.totalCommission.toStringAsFixed(0), Colors.grey),
        const SizedBox(width: 20),
        _rStat('총손익', r.totalReturn.toStringAsFixed(0), r.totalReturn >= 0 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('승률', '${(r.winRate * 100).toStringAsFixed(1)}%', r.winRate >= 0.5 ? Colors.green : Colors.red),
        const SizedBox(width: 20),
        _rStat('신호', '${r.totalSignals}', Colors.blue),
        const SizedBox(width: 20),
        _rStat('Max DD', r.maxDrawdown.toStringAsFixed(1), Colors.orange),
        const SizedBox(width: 20),
        _rStat('Sharpe', r.sharpeRatio.toStringAsFixed(2), r.sharpeRatio >= 1 ? Colors.green : Colors.grey),
      ]),
    );
  }

  Widget _tradesTable() {
    final r = _result!;
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16, dataRowMinHeight: 28, headingRowHeight: 32,
          columns: const [
            DataColumn(label: Text('진입', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('청산', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('방향', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('PnL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
          ],
          rows: r.trades.map((t) {
            final win = t.pnl > 0;
            return DataRow(
              color: WidgetStatePropertyAll(win ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05)),
              cells: [
                DataCell(Text(t.entryTime.toString().substring(0, 10), style: const TextStyle(fontSize: 11))),
                DataCell(Text(t.exitTime.toString().substring(0, 10), style: const TextStyle(fontSize: 11))),
                DataCell(Text(t.signal.name == 'strongBuy' ? 'Long' : 'Short', style: TextStyle(fontSize: 11, color: win ? Colors.green : Colors.red))),
                DataCell(Text(t.pnl.toStringAsFixed(0), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: win ? Colors.green : Colors.red))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
  ]);

  Widget _rStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
  ]);

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
            Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
        ],
        ...children,
      ]),
    );
  }
}
