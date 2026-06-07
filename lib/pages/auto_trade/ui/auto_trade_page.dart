import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auto_trade/bloc/auto_trade_bloc.dart';
import '../../../../features/auto_trade/bloc/auto_trade_event.dart';
import '../../../../features/auto_trade/bloc/auto_trade_state.dart';
import '../../../../features/auto_trade/model/dto/auto_trade_item.dart';
import '../../../../features/kis_auth/bloc/kis_auth_bloc.dart';
import '../../../../features/kis_auth/bloc/kis_auth_state.dart';
import '../../../../shared/api/kis_stock_api.dart';
import '../../../../shared/theme/font_helper.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/ui/app_card.dart';
import '../../../../shared/ui/table_row.dart';
import '../../../widgets/stock_search/ui/stock_search_field.dart';

class AutoTradePage extends StatefulWidget {
  const AutoTradePage({super.key});
  @override
  State<AutoTradePage> createState() => _AutoTradePageState();
}

class _AutoTradePageState extends State<AutoTradePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<KisAuthBloc>().state;
      if (authState is KisAuthConnected) {
        final conn = authState.connection;
        final creds = conn.active;
        if (creds?.accountNo != null) {
          final api = KisStockApi(
            appKey: creds!.appKey,
            appSecret: creds.appSecret,
            isPaper: conn.useMock,
          );
          if (creds.accessToken != null && creds.tokenExpiry != null) {
            api.setToken(creds.accessToken!, creds.tokenExpiry!);
          }
          context.read<AutoTradeBloc>().setApi(api,
            accountNo: creds.accountNo,
            productCode: creds.productCode ?? '01',
          );
        }
      }
      context.read<AutoTradeBloc>().add(const LoadItems());
      context.read<AutoTradeBloc>().startTimers();
    });
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AutoTradeBloc>().add(const LoadItems());
      context.read<AutoTradeBloc>().startTimers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<AutoTradeBloc, AutoTradeState>(
      builder: (ctx, state) {
        return ListView(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          children: [
            _header(cs, state),
            const SizedBox(height: AppConstants.spacingMd),
            _toolbar(cs, state),
            const SizedBox(height: AppConstants.spacingMd),
            _table(cs, state),
            const SizedBox(height: AppConstants.spacingMd),
            _summaryBar(cs, state),
            const SizedBox(height: AppConstants.spacingMd),
            _actionButtons(cs, state),
          ],
        );
      },
    );
  }

  Widget _header(ColorScheme cs, AutoTradeState state) {
    return Row(children: [
      Icon(Icons.swap_vert_rounded, size: 24, color: cs.primary),
      const SizedBox(width: 8),
      Text('VWAP+POC 자동거래', style: poppins(fontSize: 22, fontWeight: FontWeight.w700)),
      const Spacer(),
      _modeToggle(cs, state),
    ]);
  }

  Widget _modeToggle(ColorScheme cs, AutoTradeState state) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        _modeBtn('모의', true, state.isPaper, cs, state),
        _modeBtn('실전', false, state.isPaper, cs, state),
      ]),
    );
  }

  Widget _modeBtn(String label, bool value, bool current, ColorScheme cs, AutoTradeState state) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => context.read<AutoTradeBloc>().add(SetMode(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: inter(fontSize: 12,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _toolbar(ColorScheme cs, AutoTradeState state) {
    return Row(children: [
      SizedBox(
        width: 220,
        child: StockSearchField(
          onSelected: (stock) {
            context.read<AutoTradeBloc>().add(AddItem(code: stock.code, name: stock.name));
          },
        ),
      ),
      const Spacer(),
      Text('등록 ${state.items.length}/10', style: inter(fontSize: 12, color: cs.onSurfaceVariant)),
      const SizedBox(width: 16),
    ]);
  }

  Widget _table(ColorScheme cs, AutoTradeState state) {
    if (state.items.isEmpty) {
      return AppCard(cs: cs, title: '등록된 종목 없음', children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text('검색창에서 종목을 추가하거나 대시보드에서 우클릭하여 등록하세요.',
              style: inter(fontSize: 12, color: cs.onSurfaceVariant))),
        ),
      ]);
    }
    return AppCard(cs: cs, title: '거래 목록', children: [
      Row(children: [
        Th('코드', cs, flex: 1), Th('종목명', cs, flex: 2),
        Th('지정금액', cs, flex: 2), Th('수량', cs, flex: 1),
        Th('매수가', cs, flex: 1), Th('현재가', cs, flex: 1),
        Th('손익', cs, flex: 1), Th('상태', cs, flex: 1),
        Th('액션', cs, flex: 2),
      ]),
      const Divider(height: 1),
      SizedBox(
        height: (state.items.length * 36.0).clamp(0, 360),
        child: ListView.builder(
          itemCount: state.items.length,
          itemExtent: 36.0,
          itemBuilder: (_, i) => _itemRow(cs, state.items[i]),
        ),
      ),
    ]);
  }

  Widget _itemRow(ColorScheme cs, AutoTradeItem item) {
    final profitColor = item.profitLoss >= 0 ? Colors.red : Colors.blue;
    final profitSign = item.profitLoss >= 0 ? '+' : '';
    final statusLabel = switch (item.status) {
      TradeStatus.ready => '대기',
      TradeStatus.running => '실행중',
      TradeStatus.paused => '일시정지',
      TradeStatus.sold => '매도완료',
    };
    final statusColor = switch (item.status) {
      TradeStatus.ready => Colors.grey,
      TradeStatus.running => Colors.green,
      TradeStatus.paused => Colors.orange,
      TradeStatus.sold => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.05))),
      ),
      child: Row(children: [
        Td(item.code, flex: 1),
        Td(item.name, flex: 2),
        Td(item.allocatedAmount > 0 ? '₩${_fmt(item.allocatedAmount)}' : '-', flex: 2),
        Td('${item.quantity ?? '-'}', flex: 1),
        Td(item.entryPrice != null ? '₩${_fmt(item.entryPrice!.toInt())}' : '-', flex: 1),
        Td(item.currentPrice != null ? '₩${_fmt(item.currentPrice!.toInt())}' : '-', flex: 1),
        Td('$profitSign₩${_fmt(item.profitLoss.toInt())}',
            flex: 1, color: profitColor),
        Td(statusLabel, flex: 1, color: statusColor),
        _actions(item),
      ]),
    );
  }

  Widget _actions(AutoTradeItem item) {
    return Expanded(
      flex: 2,
      child: Row(children: [
        if (item.status == TradeStatus.ready)
          _iconBtn(Icons.play_arrow_rounded, Colors.green, () => context.read<AutoTradeBloc>().add(ItemStart(item.code))),
        if (item.status == TradeStatus.running) ...[
          _iconBtn(Icons.pause_rounded, Colors.orange, () => context.read<AutoTradeBloc>().add(ItemPause(item.code))),
          _iconBtn(Icons.stop_rounded, Colors.red, () => context.read<AutoTradeBloc>().add(ItemStop(item.code))),
        ],
        if (item.status == TradeStatus.paused)
          _iconBtn(Icons.stop_rounded, Colors.red, () => context.read<AutoTradeBloc>().add(ItemStop(item.code))),
        _iconBtn(Icons.delete_outline_rounded, Colors.grey, () => context.read<AutoTradeBloc>().add(RemoveItem(item.code))),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 28, height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon, color: color),
        onPressed: onTap,
      ),
    );
  }

  Widget _summaryBar(ColorScheme cs, AutoTradeState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text('지정합계: ₩${_fmt(state.totalAllocated)} / 잔고: ₩${_fmt(state.availableBalance.toInt())}  |  실행: ${state.runningCount}개',
          style: inter(fontSize: 11, color: cs.onSurfaceVariant)),
    );
  }

  Widget _actionButtons(ColorScheme cs, AutoTradeState state) {
    return Row(children: [
      ElevatedButton.icon(
        onPressed: state.isBatchRunning ? null : () => context.read<AutoTradeBloc>().add(const BatchStart()),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('일괄 실행'),
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: state.isBatchRunning ? null : () => context.read<AutoTradeBloc>().add(const BatchStop()),
        icon: const Icon(Icons.stop_rounded, size: 18),
        label: const Text('일괄 중지'),
      ),
      const Spacer(),
      Icon(Icons.access_time_rounded, size: 14, color: cs.onSurfaceVariant),
      const SizedBox(width: 4),
      Text('자동종료: 14:55 준비 → 15:00', style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
    ]);
  }

  String _fmt(int v) {
    if (v == 0) return '0';
    return v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
