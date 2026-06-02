import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/stock_db.dart';

class StockSearchState extends Equatable {
  final String query;
  final String market;
  final List<StockInfo> results;
  final StockInfo? selected;

  const StockSearchState({
    this.query = '',
    this.market = 'KOSPI',
    this.results = const [],
    this.selected,
  });

  StockSearchState copyWith({String? query, String? market, List<StockInfo>? results, StockInfo? selected}) {
    return StockSearchState(
      query: query ?? this.query,
      market: market ?? this.market,
      results: results ?? this.results,
      selected: selected ?? this.selected,
    );
  }

  @override
  List<Object?> get props => [query, market, results, selected];
}

class StockSearchCubit extends Cubit<StockSearchState> {
  StockSearchCubit() : super(const StockSearchState());

  void search(String query) {
    if (query.isEmpty) {
      emit(state.copyWith(query: query, results: []));
      return;
    }
    final r = searchStocks(query, market: state.market);
    emit(state.copyWith(query: query, results: r, selected: null));
  }

  void select(StockInfo stock) {
    emit(state.copyWith(selected: stock, results: [], query: stock.code));
  }

  void changeMarket(String market) {
    emit(state.copyWith(market: market, results: [], selected: null, query: ''));
  }
}
