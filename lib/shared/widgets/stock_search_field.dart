import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../features/stock_search/data/stock_db.dart';
import '../../../features/stock_search/presentation/bloc/stock_search_cubit.dart';

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

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialCode);
    _focus.addListener(() {
      if (!_focus.hasFocus) context.read<StockSearchCubit>().search('');
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<StockSearchCubit>().state;
    final results = state.results;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: state.market,
              isDense: true,
              style: GoogleFonts.inter(fontSize: 12),
              items: markets.map((m) => DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.inter(fontSize: 12)))).toList(),
              onChanged: (v) => context.read<StockSearchCubit>().changeMarket(v!),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctl,
            focusNode: _focus,
            onChanged: (v) => context.read<StockSearchCubit>().search(v),
            decoration: InputDecoration(
              hintText: '종목코드 / 이름 / 초성 검색',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              suffixIcon: state.selected != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(state.selected!.market, style: GoogleFonts.inter(fontSize: 10, color: cs.primary)),
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
              return InkWell(
                onTap: () {
                  context.read<StockSearchCubit>().select(s);
                  widget.onSelected(s);
                },
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
                    Expanded(child: Text(s.name, style: GoogleFonts.inter(fontSize: 13))),
                    Text(s.market, style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant)),
                  ]),
                ),
              );
            },
          ),
        ),
    ]);
  }
}
