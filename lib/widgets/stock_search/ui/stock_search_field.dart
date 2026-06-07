import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beyondi_trading/shared/theme/font_helper.dart';
import 'package:beyondi_trading/shared/ui/common_dropdown.dart';
import 'package:beyondi_trading/shared/data/stock_db.dart';
import 'package:beyondi_trading/features/stock_search/bloc/stock_search_cubit.dart';

class StockSearchField extends StatefulWidget {
  const StockSearchField({super.key, required this.onSelected, this.initialCode = ''});
  final void Function(StockInfo stock) onSelected;
  final String initialCode;

  @override
  State<StockSearchField> createState() => _StockSearchFieldState();
}

class _StockSearchFieldState extends State<StockSearchField> {
  late final TextEditingController _ctl;
  final _focus = FocusNode();
  int _highlightIndex = -1;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialCode);
    _focus.onKeyEvent = _onKeyEvent;
  }

  @override
  void didUpdateWidget(StockSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCode != oldWidget.initialCode && widget.initialCode.isNotEmpty) {
      _ctl.text = widget.initialCode;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _select(StockInfo s) {
    _ctl.text = s.code;
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    _highlightIndex = -1;
    widget.onSelected(s);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockSearchCubit>().select(s);
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final results = context.read<StockSearchCubit>().state.results;
    if (results.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlightIndex = (_highlightIndex + 1) % results.length);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlightIndex = (_highlightIndex - 1 + results.length) % results.length);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightIndex >= 0 && _highlightIndex < results.length) {
        _select(results[_highlightIndex]);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      context.read<StockSearchCubit>().search('');
      _highlightIndex = -1;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<StockSearchCubit>().state;
    final results = state.results;

    if (_highlightIndex >= results.length) _highlightIndex = -1;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CommonDropdown<String>(
            value: state.market,
            items: markets.map((m) => DropdownItem(m, m)).toList(),
            onChanged: (v) {
              context.read<StockSearchCubit>().changeMarket(v);
              _highlightIndex = -1;
            },
          ),
        Expanded(
          child: TextField(
            controller: _ctl,
            focusNode: _focus,
            onChanged: (v) {
              context.read<StockSearchCubit>().search(v);
              _highlightIndex = -1;
            },
            decoration: InputDecoration(
              hintText: '종목코드 / 이름 / 초성 검색',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              suffixIcon: state.selected != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(state.selected!.market, style: inter(fontSize: 10, color: cs.primary)),
                    )
                  : null,
            ),
            enableInteractiveSelection: true,
          ),
        ),
      ]),
      if (results.isNotEmpty)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (_, i) {
              final s = results[i];
              final q = _ctl.text.toUpperCase();
              final codeMatch = s.code.toUpperCase().contains(q);
              return Container(
                color: i == _highlightIndex ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
                child: InkWell(
                onTap: () => _select(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: codeMatch ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(s.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.name, style: inter(fontSize: 13))),
                      Text(s.market, style: inter(fontSize: 10, color: cs.onSurfaceVariant)),
                    ]),
                ),
              ),
              );
            },
          ),
        ),
    ]);
  }
}
