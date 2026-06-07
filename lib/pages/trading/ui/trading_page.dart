import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_bloc.dart';
import 'package:beyondi_trading/features/kis_auth/bloc/kis_auth_state.dart';
import 'package:beyondi_trading/features/trading/api/kis_trading_repository.dart';
import 'package:beyondi_trading/entities/order_record/model/order_record.dart';
import 'package:beyondi_trading/entities/trading_position/model/trading_position.dart';
import 'package:beyondi_trading/features/trading/bloc/trading_bloc.dart';
import 'package:beyondi_trading/features/trading/bloc/trading_event.dart';
import 'package:beyondi_trading/features/trading/bloc/trading_state.dart';
import 'package:beyondi_trading/shared/constants/app_constants.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';
import 'package:beyondi_trading/shared/ui/app_card.dart';
import 'package:beyondi_trading/shared/ui/table_row.dart';
import 'package:beyondi_trading/widgets/stock_search/ui/stock_search_field.dart';

class TradingPage extends StatefulWidget {
  const TradingPage({super.key});
  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> {
  final _qtyCtl = TextEditingController(text: '1');
  final _priceCtl = TextEditingController(text: '0');
  final _symbolCtl = TextEditingController(text: '005930');
  String _orderDivision = '00';
  TradingBloc? _bloc;
  String? _lastCredKey;

  @override
  void dispose() {
    _qtyCtl.dispose();
    _priceCtl.dispose();
    _symbolCtl.dispose();
    _bloc?.close();
    super.dispose();
  }

  KisStockApi? _buildApi(KisAuthState authState) {
    if (authState is! KisAuthConnected) return null;
    final c = authState.connection;
    final a = c.active;
    if (a == null) return null;
    return KisStockApi(appKey: a.appKey, appSecret: a.appSecret, isPaper: c.useMock);
  }

  String? _getAccount(KisAuthState authState) {
    if (authState is! KisAuthConnected) return null;
    return authState.connection.active?.accountNo;
  }

  String? _getProductCode(KisAuthState authState) {
    if (authState is! KisAuthConnected) return null;
    return authState.connection.active?.productCode ?? '01';
  }

  void _ensureBloc(KisAuthState authState) {
    final api = _buildApi(authState);
    final account = _getAccount(authState);
    final product = _getProductCode(authState);
    if (api == null || account == null || product == null) return;
    final credKey = '${api.appKey}|$account';
    if (_bloc != null && _lastCredKey == credKey) return;
    _bloc?.close();
    _lastCredKey = credKey;
    _bloc = TradingBloc(
      repository: KisTradingRepository(api: api),
      accountNo: account,
      productCode: product,
    );
    _bloc!.add(const TradingFetchPositions());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authState = context.watch<KisAuthBloc>().state;
    final connected = authState is KisAuthConnected && authState.connection.isTokenValid;
    final api = _buildApi(authState);

    if (connected && api != null) _ensureBloc(authState);

    if (!connected) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_wallet_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('KIS 연결 필요', style: poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('우측 상단 KIS 뱃지를 탭하여 연결하세요', style: inter(fontSize: 14, color: Colors.grey.withValues(alpha: 0.4))),
        ]),
      );
    }

    final bloc = _bloc;
    if (bloc == null) {
      return Center(child: Text('계좌 정보를 불러오는 중...', style: inter(fontSize: 14)));
    }

    return BlocProvider.value(
      value: bloc,
      child: Builder(builder: (ctx) {
        final st = ctx.watch<TradingBloc>().state;
        final loading = st is TradingLoading;
        final loaded = st is TradingLoaded;

        return Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            children: [
              Row(children: [
                Text('실시간 매매', style: poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('LIVE', style: inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('KIS Open API 실시간 주문 · 수수료 0.147%', style: inter(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),

              if (loaded && st.lastOrderResult != null) _resultCard(cs, st.lastOrderResult!),
              if (loaded && st.error != null) _errorCard(cs, st.error!),

              AppCard(cs: cs, title: '주문', children: [
                Row(children: [
                  Expanded(child: StockSearchField(
                    onSelected: (stock) {
                      _symbolCtl.text = stock.code;
                      ctx.read<TradingBloc>().add(TradingSymbolChanged(stock.code));
                    },
                    initialCode: _symbolCtl.text,
                  )),
                ]),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    SizedBox(width: 80, child: TextField(
                      controller: _qtyCtl,
                      decoration: const InputDecoration(labelText: '수량', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 100, child: TextField(
                      controller: _priceCtl,
                      decoration: const InputDecoration(labelText: '가격 (0=시장가)', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 8),
                    _orderTypeDropdown(),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: loading ? null : () => _submitOrder(ctx, 'buy'),
                      icon: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.shopping_cart_rounded, size: 16),
                      label: const Text('매수'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: loading ? null : () => _submitOrder(ctx, 'sell'),
                      icon: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sell_rounded, size: 16),
                      label: const Text('매도'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ]),
                ),
              ]),

              if (loaded) ...[
                const SizedBox(height: 12),
                AppCard(cs: cs, title: '보유 포지션', children: [
                  if (st.positions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('보유 종목 없음', style: inter(fontSize: 13, color: Colors.grey))),
                    )
                  else
                    _positionsTable(cs, st.positions),
                ]),
                const SizedBox(height: 12),
                AppCard(cs: cs, title: '최근 주문', children: [
                  if (st.orders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('주문 내역 없음', style: inter(fontSize: 13, color: Colors.grey))),
                    )
                  else
                    _ordersTable(cs, st.orders),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      final start = now.subtract(const Duration(days: 7));
                      final fmt = '${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}';
                      final fmtEnd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
                      ctx.read<TradingBloc>().add(TradingFetchOrders(startDate: fmt, endDate: fmtEnd));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('주문 내역 갱신', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _resultCard(ColorScheme cs, Map<String, dynamic> result) {
    final msg = result['msg1'] as String? ?? '주문 전송 완료';
    final odno = result['odno'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text('$msg (주문번호: $odno)', style: inter(fontSize: 11, color: Colors.green.shade800))),
        ]),
      ),
    );
  }

  Widget _errorCard(ColorScheme cs, String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_rounded, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: inter(fontSize: 11, color: Colors.red.shade800))),
        ]),
      ),
    );
  }

  Widget _orderTypeDropdown() {
    final types = {'00': '지정가', '01': '시장가', '02': '조건부지정가'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _orderDivision,
          items: types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _orderDivision = v ?? '00'),
          isDense: true,
        ),
      ),
    );
  }

  void _submitOrder(BuildContext ctx, String side) {
    final sym = _symbolCtl.text.trim();
    if (sym.isEmpty) return;
    final qty = int.tryParse(_qtyCtl.text) ?? 1;
    final price = double.tryParse(_priceCtl.text) ?? 0;
    if (qty <= 0) return;
    if (side == 'buy') {
      ctx.read<TradingBloc>().add(TradingBuyRequested(symbol: sym, quantity: qty, price: price, orderDivision: _orderDivision));
    } else {
      ctx.read<TradingBloc>().add(TradingSellRequested(symbol: sym, quantity: qty, price: price, orderDivision: _orderDivision));
    }
  }

  Widget _positionsTable(ColorScheme cs, List<TradingPosition> positions) {
    return Column(children: [
      Row(children: [
        Th('종목코드', cs, flex: 1),
        Th('종목명', cs, flex: 2),
        Th('수량', cs, flex: 1),
        Th('평균단가', cs, flex: 1),
        Th('현재가', cs, flex: 1),
        Th('평가손익', cs, flex: 1),
        Th('수익률', cs, flex: 1),
      ]),
      SizedBox(
        height: (positions.length * 28.0).clamp(0, 200),
        child: ListView.builder(
          itemCount: positions.length,
          itemExtent: 28.0,
          itemBuilder: (_, i) {
            final p = positions[i];
            final isProfit = p.profitLoss >= 0;
            return Container(
              color: isProfit ? Colors.red.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
              child: Row(children: [
                Td(p.symbol, flex: 1),
                Td(p.name, flex: 2),
                Td('${p.quantity}', flex: 1),
                Td('₩${_fmt(p.avgPrice)}', flex: 1),
                Td('₩${_fmt(p.currentPrice)}', flex: 1),
                Td('${isProfit ? '+' : ''}₩${_fmt(p.profitLoss)}', flex: 1, color: isProfit ? Colors.red : Colors.blue),
                Td('${isProfit ? '+' : ''}${p.profitRate.toStringAsFixed(1)}%', flex: 1, color: isProfit ? Colors.red : Colors.blue),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _ordersTable(ColorScheme cs, List<OrderRecord> orders) {
    return Column(children: [
      Row(children: [
        Th('주문번호', cs, flex: 2),
        Th('종목', cs, flex: 1),
        Th('구분', cs, flex: 1),
        Th('수량', cs, flex: 1),
        Th('가격', cs, flex: 1),
        Th('체결', cs, flex: 1),
        Th('상태', cs, flex: 1),
      ]),
      SizedBox(
        height: (orders.length * 28.0).clamp(0, 200),
        child: ListView.builder(
          itemCount: orders.length,
          itemExtent: 28.0,
          itemBuilder: (_, i) {
            final o = orders[i];
            final sideColor = o.isBuy ? Colors.red : Colors.blue;
            return Row(children: [
              Td(o.orderNo.length > 8 ? o.orderNo.substring(0, 8) : o.orderNo, flex: 2),
              Td(o.symbol, flex: 1),
              Td(o.isBuy ? '매수' : '매도', flex: 1, color: sideColor),
              Td('${o.quantity}', flex: 1),
              Td('₩${_fmt(o.price)}', flex: 1),
              Td('${o.filledQuantity}/${o.quantity}', flex: 1),
              Td(_statusLabel(o.status), flex: 1, color: _statusColor(o.status)),
            ]);
          },
        ),
      ),
    ]);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'filled': return '체결';
      case 'partial': return '부분체결';
      case 'pending': return '미체결';
      case 'cancelled': return '취소';
      case 'rejected': return '거부';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'filled': return Colors.green;
      case 'partial': return Colors.orange;
      case 'pending': return Colors.blue;
      case 'cancelled': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    return v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
