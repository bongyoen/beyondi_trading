import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/features/backtest/api/candle_cache.dart';
import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/entities/candle/model/candle.dart';
import 'package:beyondi_trading/features/backtest/model/usecases/run_backtest.dart';
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

      // 캐시가 전부 커버되면 그대로 사용. 아니라면 누락 구간만 다운로드.
      if (cached != null && cached.length > 200) {
        final coversStart = !cached.first.timestamp.isAfter(event.startDate);
        final coversEnd = !event.endDate.isAfter(cached.last.timestamp) ||
            event.endDate.difference(cached.last.timestamp).inDays.abs() <= 2;
        if (coversStart && coversEnd) {
          final filtered = cached.where((c) =>
            !c.timestamp.isBefore(event.startDate) &&
            !c.timestamp.isAfter(event.endDate)).toList();
          emit(BacktestDataLoaded(candles: filtered.length > 50 ? filtered : cached,
              status: '${filtered.length}개 캔들 (캐시)'));
          return;
        }
      }

      // 누락된 구간 계산
      final api = KisStockApi(
        appKey: event.appKey, appSecret: event.appSecret, isPaper: event.isPaper,
      );

      // 시작일 이전 누락: startDate ~ (첫캔들 전일)
      // 종료일 이후 누락: (마지막캔들 다음일) ~ endDate
      final frontStart = event.startDate;
      final frontEnd = (cached != null && cached.isNotEmpty)
          ? cached.first.timestamp.subtract(const Duration(days: 1))
          : null;
      final backStart = (cached != null && cached.isNotEmpty)
          ? cached.last.timestamp.add(const Duration(days: 1))
          : event.startDate;
      final backEnd = event.endDate;

      final all = <Candle>[];
      if (cached != null) all.addAll(cached);
      int failed = 0;

      if (event.isMinute) {
        // 앞쪽 누락 다운로드
        if (frontEnd != null && !frontEnd.isBefore(frontStart)) {
          final (added, err) = await _downloadMinuteRange(api, event.symbol, frontStart, frontEnd, all, emit);
          all.addAll(added);
          failed += err;
        }
        // 뒤쪽 누락 다운로드
        if (!backStart.isAfter(backEnd)) {
          final (added, err) = await _downloadMinuteRange(api, event.symbol, backStart, backEnd, all, emit);
          all.addAll(added);
          failed += err;
        }
      } else {
        // 일봉: 앞쪽
        if (frontEnd != null && !frontEnd.isBefore(frontStart)) {
          final (added, err) = await _downloadDailyRange(api, event.symbol, frontStart, frontEnd, all, emit);
          all.addAll(added);
          failed += err;
        }
        // 일봉: 뒤쪽
        if (!backStart.isAfter(backEnd)) {
          final (added, err) = await _downloadDailyRange(api, event.symbol, backStart, backEnd, all, emit);
          all.addAll(added);
          failed += err;
        }
      }

      all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // 중복 제거
      final seen = <DateTime>{};
      final deduped = all.where((c) => seen.add(c.timestamp)).toList();

      // 날짜 범위 필터링 (사용자 설정 기간)
      final rangeFiltered = deduped.where((c) =>
        !c.timestamp.isBefore(event.startDate) &&
        !c.timestamp.isAfter(event.endDate)).toList();
      final display = rangeFiltered.length > 50 ? rangeFiltered : deduped;

      await _cache.save(symbol: event.symbol, start: event.startDate, end: event.endDate, candles: deduped);
      emit(BacktestDataLoaded(
        candles: display,
        status: '${display.length}개 캔들${failed > 0 ? " (${failed}일 실패)" : ""}${deduped.length - display.length > 0 ? " (${deduped.length - display.length}개 범위외)" : ""}',
      ));
    } catch (e) {
      emit(BacktestError(message: e.toString()));
    }
  }

  Future<(List<Candle>, int)> _downloadMinuteRange(
    KisStockApi api, String symbol, DateTime from, DateTime to,
    List<Candle> existing, Emitter<BacktestState> emit,
  ) async {
    final result = <Candle>[];
    int failed = 0;
    int done = 0;
    final startDay = DateTime(from.year, from.month, from.day);
    final endDay = DateTime(to.year, to.month, to.day);
    final total = endDay.difference(startDay).inDays + 1;

    for (int d = 0; d < total; d++) {
      final date = startDay.add(Duration(days: d));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
      List<Candle>? chunk;
      for (int retry = 0; retry < 3; retry++) {
        try {
          chunk = await api.fetchMinuteCandles(symbol: symbol, date: date);
          break;
        } catch (_) {
          if (retry < 2) await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      if (chunk != null && chunk.isNotEmpty) {
        result.addAll(chunk);
        done++;
      } else {
        // 실패 시 휴일인지 확인 → 휴일이면 패스, 아니면 failed++
        final df = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        try {
          if (await api.checkHoliday(df)) continue;
        } catch (_) {}
        failed++;
      }
      await Future.delayed(const Duration(milliseconds: 50));
      if ((done + failed) % 5 == 0 || d == total - 1) {
        emit(BacktestDataLoading(
          status: '분봉 로딩... $done/${done + failed}일 (${result.length}캔들${failed > 0 ? ", ${failed}일 실패" : ""})',
          candles: [...existing, ...result],
        ));
      }
    }
    return (result, failed);
  }

  Future<(List<Candle>, int)> _downloadDailyRange(
    KisStockApi api, String symbol, DateTime from, DateTime to,
    List<Candle> existing, Emitter<BacktestState> emit,
  ) async {
    final result = <Candle>[];
    int failed = 0;
    DateTime cursor = to;

    while (true) {
      final chunk = await api.fetchDailyCandles(symbol: symbol, start: from, end: cursor);
      if (chunk.isEmpty) { failed++; break; }
      for (final c in chunk) {
        if (!result.any((e) => e.timestamp == c.timestamp)) result.add(c);
      }
      emit(BacktestDataLoading(
        status: '일봉 로딩... ${result.length}캔들', candles: [...existing, ...result],
      ));
      if (chunk.last.timestamp.isBefore(from) || chunk.last.timestamp == from) break;
      cursor = chunk.last.timestamp.subtract(const Duration(days: 1));
    }
    return (result, failed);
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
        consecutiveLossLimit: event.consecutiveLossLimit,
        dailyLossLimit: event.dailyLossLimit,
        maxTotalLoss: event.maxTotalLoss,
        useAtrPositionSizing: event.useAtrPositionSizing,
        longOnly: event.longOnly,
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
