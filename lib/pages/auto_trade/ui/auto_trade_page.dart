import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auto_trade/bloc/auto_trade_bloc.dart';
import '../../../../features/auto_trade/bloc/auto_trade_event.dart';
import '../../../../features/auto_trade/bloc/auto_trade_state.dart';
import '../../../../features/auto_trade/model/dto/auto_trade_item.dart';
import '../../../../entities/kis_connection/model/kis_connection.dart';
import '../../../../features/kis_auth/bloc/kis_auth_bloc.dart';
import '../../../../features/kis_auth/bloc/kis_auth_state.dart';
import '../../../../shared/api/kis_stock_api.dart';
import '../../../../shared/theme/font_helper.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/ui/app_card.dart';
import '../../../../shared/ui/common_button.dart';
import '../../../../shared/ui/input_field.dart';
import '../../../../shared/ui/table_row.dart';
import '../../../widgets/stock_search/ui/stock_search_field.dart';

class AutoTradePage extends StatefulWidget {
  const AutoTradePage({super.key});
  @override
  State<AutoTradePage> createState() => _AutoTradePageState();
}

class _AutoTradePageState extends State<AutoTradePage> {
  String? _lastApiCredKey;

  void _ensureAutoTradeApi(KisConnection conn) {
    for (final entry in [
      (creds: conn.mock, isMock: true),
      (creds: conn.real, isMock: false),
    ]) {
      final c = entry.creds;
      if (c == null) continue;
      final key = '${c.appKey}|${entry.isMock}';
      if (_lastApiCredKey == key) continue;
      _lastApiCredKey = key;
      final api = KisStockApi(
        appKey: c.appKey,
        appSecret: c.appSecret,
        isPaper: entry.isMock,
      );
      if (c.accessToken != null && c.tokenExpiry != null) {
        api.setToken(c.accessToken!, c.tokenExpiry!);
      }
      context.read<AutoTradeBloc>().setApi(api,
        accountNo: c.accountNo,
        productCode: c.productCode ?? '01',
        isMock: entry.isMock,
      );
    }
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
    final authState = context.watch<KisAuthBloc>().state;
    if (authState is KisAuthConnected) _ensureAutoTradeApi(authState.connection);
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
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                Text(item.currentPrice != null ? '₩${_fmt(item.currentPrice!.toInt())}' : '-',
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 32,
            child: CommonInputField(
              label: '',
              hint: '금액',
              controller: TextEditingController(text: item.allocatedAmount > 0 ? '${item.allocatedAmount}' : ''),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixText: '₩ ',
              isDense: true,
              onSubmitted: (v) {
                final amt = int.tryParse(v) ?? 0;
                context.read<AutoTradeBloc>().add(UpdateAmount(code: item.code, amount: amt));
              },
            ),
          ),
        ),
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
          CommonIconButton(icon: Icons.play_arrow_rounded, color: Colors.green, onPressed: () => context.read<AutoTradeBloc>().add(ItemStart(item.code))),
        if (item.status == TradeStatus.running) ...[
          CommonIconButton(icon: Icons.pause_rounded, color: Colors.orange, onPressed: () => context.read<AutoTradeBloc>().add(ItemPause(item.code))),
          CommonIconButton(icon: Icons.stop_rounded, color: Colors.red, onPressed: () => context.read<AutoTradeBloc>().add(ItemStop(item.code))),
        ],
        if (item.status == TradeStatus.paused)
          CommonIconButton(icon: Icons.stop_rounded, color: Colors.red, onPressed: () => context.read<AutoTradeBloc>().add(ItemStop(item.code))),
        CommonIconButton(icon: Icons.delete_outline_rounded, color: Colors.grey, onPressed: () => context.read<AutoTradeBloc>().add(RemoveItem(item.code))),
      ]),
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
      CommonButton(
        label: '일괄 실행',
        icon: Icons.play_arrow_rounded,
        onPressed: state.isBatchRunning ? null : () => context.read<AutoTradeBloc>().add(const BatchStart()),
      ),
      const SizedBox(width: 12),
      CommonButton(
        label: '일괄 중지',
        icon: Icons.stop_rounded,
        style: CommonButtonStyle.outlined,
        onPressed: state.isBatchRunning ? null : () => context.read<AutoTradeBloc>().add(const BatchStop()),
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
