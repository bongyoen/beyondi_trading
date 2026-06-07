import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/candle_cache.dart';
import '../../data/datasources/kis_stock_api.dart';
import '../../domain/entities/candle.dart';
import '../../domain/usecases/run_backtest.dart';
import 'backtest_event.dart';
import 'backtest_state.dart';

class BacktestBloc extends Bloc<BacktestEvent, BacktestState> {
  final CandleCache _cache = CandleCache();

  BacktestBloc() : super(const BacktestInitial()) {
    on<BacktestLoadData>(_onLoadData);
    on<BacktestRun>(_onRun);
    on<BacktestDeleteCache>(_onDeleteCache);
  }

  Future<void> _onLoadData(BacktestLoadData event, Emitter<BacktestState> emit) async {
    emit(const BacktestDataLoading(status: '캐시 확인 중...'));

    try {
      final cached = await _cache.load(
        symbol: event.symbol, start: event.startDate, end: event.endDate,
      );
      if (cached != null && cached.length > 50) {
        final firstOk = !cached.first.timestamp.isAfter(event.startDate) ||
            cached.first.timestamp.difference(event.startDate).inDays.abs() <= 2;
        final lastOk = !event.endDate.isAfter(cached.last.timestamp) ||
            event.endDate.difference(cached.last.timestamp).inDays.abs() <= 2;
        if (firstOk && lastOk) {
          emit(BacktestDataLoaded(candles: cached, status: '${cached.length}개 캔들 (캐시)'));
          return;
        }
      }

      final api = KisStockApi(
        appKey: event.appKey, appSecret: event.appSecret, isPaper: event.isPaper,
      );

      final all = <Candle>[];
      int failed = 0;
      if (event.isMinute) {
        int done = 0;
        for (int d = 0; d <= event.endDate.difference(event.startDate).inDays; d++) {
          final date = event.startDate.add(Duration(days: d));
          if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
          List<Candle>? chunk;
          for (int retry = 0; retry < 3; retry++) {
            try {
              chunk = await api.fetchMinuteCandles(symbol: event.symbol, date: date);
              break;
            } catch (_) {
              if (retry < 2) await Future.delayed(const Duration(milliseconds: 500));
            }
          }
          if (chunk != null && chunk.isNotEmpty) {
            all.addAll(chunk);
            done++;
          } else {
            failed++;
          }
          await Future.delayed(const Duration(milliseconds: 50));
          if ((done + failed) % 5 == 0 || d == event.endDate.difference(event.startDate).inDays) {
            emit(BacktestDataLoading(
              status: '분봉 로딩... $done/${done + failed}일 (${all.length}캔들${failed > 0 ? ", ${failed}일 실패" : ""})',
              candles: List.of(all),
            ));
          }
        }
      } else {
        DateTime cursor = event.endDate;
        while (true) {
          final from = cursor.subtract(const Duration(days: 100));
          final cs = from.isAfter(event.startDate) ? from : event.startDate;
          final chunk = await api.fetchDailyCandles(symbol: event.symbol, start: cs, end: cursor);
          if (chunk.isEmpty) break;
          for (final c in chunk) {
            if (!all.any((e) => e.timestamp == c.timestamp)) all.add(c);
          }
          emit(BacktestDataLoading(
            status: '로딩 중... ${all.length}캔들', candles: List.of(all),
          ));
          if (cs == event.startDate) break;
          cursor = cs.subtract(const Duration(days: 1));
        }
      }

      all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      await _cache.save(symbol: event.symbol, start: event.startDate, end: event.endDate, candles: all);
      emit(BacktestDataLoaded(
        candles: all,
        status: '${all.length}개 캔들 로드 완료${failed > 0 ? " (${failed}일 실패)" : ""}',
      ));
    } catch (e) {
      emit(BacktestError(message: e.toString()));
    }
  }

  Future<void> _onRun(BacktestRun event, Emitter<BacktestState> emit) async {
    final current = state;
    if (current is! BacktestDataLoaded && current is! BacktestCompleted && current is! BacktestError) return;
    List<Candle>? candles;
    if (current is BacktestDataLoaded) candles = current.candles;
    else if (current is BacktestCompleted) candles = current.candles;
    else if (current is BacktestError) candles = current.candles;
    if (candles == null || candles.isEmpty) return;

    emit(BacktestRunning(candles: candles));
    await Future.delayed(Duration.zero);

    try {
      final result = runBacktest(
        candles: candles,
        tickSize: event.tickSize,
        adaptiveMode: event.adaptiveMode,
        entryThresholdTicks: event.entryThresholdTicks,
        takeProfitTicks: event.takeProfitTicks,
        stopLossTicks: event.stopLossTicks,
        stopLossPercent: event.stopLossPercent,
        useAtrStop: event.useAtrStop,
        atrMultiplier: event.atrMultiplier,
        useRsiFilter: event.useRsiFilter,
        rsiOversold: event.rsiOversold,
        rsiOverbought: event.rsiOverbought,
        closeAtEndOfDay: true,
        mode: event.mode,
        commissionPercent: event.commissionPercent,
        principal: event.principal,
      );
      await _cache.saveResult(symbol: event.symbol, tickSize: event.tickSize, result: result);
      emit(BacktestCompleted(candles: candles, result: result));
    } catch (e) {
      emit(BacktestError(message: e.toString(), candles: candles));
    }
  }

  Future<void> _onDeleteCache(BacktestDeleteCache event, Emitter<BacktestState> emit) async {
    await _cache.delete(
      symbol: event.symbol, start: event.startDate, end: event.endDate, tickSize: event.tickSize,
    );
    emit(const BacktestInitial());
  }
}
