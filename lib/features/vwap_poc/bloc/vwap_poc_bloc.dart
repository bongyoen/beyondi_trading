import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:beyondi_trading/shared/api/api_logger.dart';
import 'package:beyondi_trading/shared/api/kis_stock_api.dart';
import 'package:beyondi_trading/entities/candle/model/candle.dart';
import 'package:beyondi_trading/shared/data/stock_db.dart';
import 'package:beyondi_trading/features/vwap_poc/model/dto/vwap_poc_item.dart';
import 'vwap_poc_event.dart';
import 'vwap_poc_state.dart';

class VwapPocBloc extends Bloc<VwapPocEvent, VwapPocState> {
  KisStockApi? _api;
  DateTime? _lastFailAt;

  VwapPocBloc() : super(const VwapPocInitial()) {
    on<VwapPocRequested>(_onRequested);
    on<VwapPocRefreshRequested>(_onRefreshRequested);
  }

  void setApi(KisStockApi api) => _api = api;

  String get _dir =>
      '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';

  Future<void> _onRequested(
      VwapPocRequested event, Emitter<VwapPocState> emit) async {
    if (state is VwapPocLoading) return;

    // 60s 쿨다운
    if (_lastFailAt != null &&
        DateTime.now().difference(_lastFailAt!).inSeconds < 60) {
      return;
    }

    emit(const VwapPocLoading());

    // 캐시 우선 확인
    final cached = await _loadCache();
    if (cached != null) {
      emit(VwapPocLoaded(items: cached.items, lastUpdated: cached.lastUpdated));
      return;
    }

    await _fetchAndScore(emit);
  }

  Future<void> _onRefreshRequested(
      VwapPocRefreshRequested event, Emitter<VwapPocState> emit) async {
    await _fetchAndScore(emit);
  }

  Future<({List<VwapPocItem> items, DateTime lastUpdated})?> _loadCache() async {
    try {
      final file = File('$_dir\\vwap_poc_top10.json');
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      final data = jsonDecode(raw) as List<dynamic>;
      if (data.isEmpty) return null;

      final first = data.first as Map<String, dynamic>;
      final lastUpdate = DateTime.tryParse(
          (first['lastUpdatedAt'] as String?) ?? '');
      if (lastUpdate == null) return null;

      // 마지막 영업일 계산
      final now = DateTime.now();
      var lastBiz = now.weekday == DateTime.saturday
          ? now.subtract(const Duration(days: 1))
          : now.weekday == DateTime.sunday
              ? now.subtract(const Duration(days: 2))
              : now;
      if (lastUpdate.isBefore(DateTime(lastBiz.year, lastBiz.month, lastBiz.day))) {
        return null; // 캐시가 오래됨
      }

      return (
        items: data
            .map((e) => VwapPocItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        lastUpdated: lastUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchAndScore(Emitter<VwapPocState> emit) async {
    if (_api == null) {
      emit(const VwapPocFailure('API 인증 정보가 없습니다. KIS 연결 후 다시 시도하세요.'));
      return;
    }

    emit(const VwapPocLoading());

    try {
      await ApiLogger.log(
          module: 'SCREEN',
          method: 'START',
          url: 'vwap_poc screen',
          summary: '등락률순위 조회 시작');

      final now = DateTime.now();
      var lastBiz = now.weekday == DateTime.saturday
          ? now.subtract(const Duration(days: 1))
          : now.weekday == DateTime.sunday
              ? now.subtract(const Duration(days: 2))
              : now;
      final lastBizDay = DateTime(lastBiz.year, lastBiz.month, lastBiz.day);

      // 등락률순위 Top 50
      List<Map<String, dynamic>> rankData;
      try {
        rankData = await _api!.fetchFluctuationRank(divCode: '000', count: 50);
      } catch (e) {
        rankData = [];
        await ApiLogger.log(
            module: 'SCREEN',
            method: 'GET',
            url: '/ranking/fluctuation',
            error: e.toString());
      }

      // API 실패 → 캐시 fallback
      if (rankData.isEmpty) {
        final cached = await _loadCache();
        if (cached != null) {
          emit(VwapPocLoaded(items: cached.items, lastUpdated: cached.lastUpdated));
          return;
        }
        emit(const VwapPocFailure('등락률순위 API 조회 실패'));
        return;
      }

      // 종목명 맵
      final nameMap = <String, String>{};
      for (final s in stockDb) {
        nameMap[s.code] = s.name;
      }

      final results = <VwapPocItem>[];
      final startDate = lastBizDay.subtract(const Duration(days: 25));

      for (final item in rankData) {
        final code = (item['stck_shrn_iscd'] ?? '') as String;
        if (code.isEmpty) continue;

        var dailyCandles = _loadDailyCandles(code);
        final lastCandleDay = dailyCandles.isNotEmpty
            ? DateTime(dailyCandles.last.timestamp.year,
                dailyCandles.last.timestamp.month,
                dailyCandles.last.timestamp.day)
            : null;

        if (lastCandleDay == null || lastCandleDay.isBefore(lastBizDay)) {
          try {
            final start = lastCandleDay != null
                ? lastCandleDay.add(const Duration(days: 1))
                : startDate;
            final chunk =
                await _api!.fetchDailyCandles(symbol: code, start: start, end: lastBizDay);
            if (chunk.isNotEmpty) {
              dailyCandles.addAll(chunk);
              dailyCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              _saveDailyCandles(code, dailyCandles);
            }
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (dailyCandles.length < 10) continue;

        final closes = dailyCandles.map((c) => c.close).toList();
        final avgPrice = closes.reduce((a, b) => a + b) / closes.length;
        final lastClose = dailyCandles.last.close;
        final tickSize = _tickSize(avgPrice);
        final vwap = _calcDailyVwap(dailyCandles);
        final ci = _calcDailyCi(dailyCandles);
        final vwapSlope =
            vwap.length >= 5 ? (vwap.last - vwap[vwap.length - 5]) / 5 : 0.0;
        final vwapDist = (lastClose - vwap.last).abs() / tickSize;
        final periodReturn = closes.length > 1
            ? (closes.last - closes.first) / closes.first * 100
            : 0.0;
        final atr5 = _calcDailyAtr(dailyCandles, 5);
        final atr20 = _calcDailyAtr(
            dailyCandles, closes.length > 20 ? 20 : closes.length);
        final atrRatio = atr20 > 0 ? atr5 / atr20 : 1.0;

        int score = 0;
        if (ci < 50) score += 3;
        else if (ci >= 52) score -= 1;
        if (vwapDist >= 3 && vwapDist <= 20) score += 2;
        if (periodReturn > 0) score += 2;
        if (vwapSlope > 0) score += 2;
        if (atrRatio >= 0.8) score += 1;

        results.add(VwapPocItem(
          code: code,
          name: nameMap[code] ?? code,
          score: score,
          ci: ci,
          vwapDist: vwapDist,
          vwapSlope: vwapSlope,
          periodReturn: periodReturn,
          atrRatio: atrRatio,
          close: lastClose,
          vwap: vwap.last,
        ));
      }

      results.sort((a, b) => b.score.compareTo(a.score));
      final top10 = results.take(10).toList();

      await ApiLogger.log(
          module: 'SCREEN',
          method: 'DONE',
          url: 'vwap_poc screen',
          summary: '${results.length}개 종목 분석 완료, Top 10 저장');

      _saveCache(top10, lastBizDay);

      emit(VwapPocLoaded(items: top10, lastUpdated: lastBizDay));
    } catch (e) {
      final cache = await _loadCache();
      if (cache != null) {
        emit(VwapPocLoaded(items: cache.items, lastUpdated: cache.lastUpdated));
      } else {
        emit(VwapPocFailure('스크리닝 실패: $e'));
      }
    }
  }

  // ---- 파일 I/O ----

  void _saveCache(List<VwapPocItem> items, DateTime date) {
    try {
      final file = File('$_dir\\vwap_poc_top10.json');
      final json = items.map((e) => {
        ...e.toJson(),
        'lastUpdatedAt': date.toIso8601String(),
      }).toList();
      file.writeAsStringSync(jsonEncode(json));
    } catch (_) {}
  }

  List<Candle> _loadDailyCandles(String code) {
    try {
      final f = File('$_dir\\daily_${code}_full_1d.json');
      if (!f.existsSync()) return [];
      final raw = jsonDecode(f.readAsStringSync()) as List<dynamic>;
      return raw.map((e) => Candle(
        timestamp: DateTime.parse(e['t'] as String),
        open: (e['o'] as num).toDouble(),
        high: (e['h'] as num).toDouble(),
        low: (e['l'] as num).toDouble(),
        close: (e['c'] as num).toDouble(),
        volume: (e['v'] as num).toDouble(),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  void _saveDailyCandles(String code, List<Candle> candles) {
    try {
      final f = File('$_dir\\daily_${code}_full_1d.json');
      final json = candles.map((c) => {
        't': c.timestamp.toIso8601String(),
        'o': c.open,
        'h': c.high,
        'l': c.low,
        'c': c.close,
        'v': c.volume,
      }).toList();
      f.writeAsStringSync(jsonEncode(json));
    } catch (_) {}
  }

  // ---- 계산 헬퍼 ----

  List<double> _calcDailyVwap(List<Candle> candles) {
    final vwap = <double>[];
    double tpv = 0, vol = 0;
    for (final c in candles) {
      final tp = (c.high + c.low + c.close) / 3;
      tpv += tp * c.volume;
      vol += c.volume;
      vwap.add(vol > 0 ? tpv / vol : c.close);
    }
    return vwap;
  }

  double _calcDailyCi(List<Candle> candles, {int period = 14}) {
    if (candles.length < period + 1) return 50;
    final tr = <double>[];
    tr.add(candles[0].high - candles[0].low);
    for (int i = 1; i < candles.length; i++) {
      final hl = candles[i].high - candles[i].low;
      final hc = (candles[i].high - candles[i - 1].close).abs();
      final lc = (candles[i].low - candles[i - 1].close).abs();
      tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
    }
    final last = candles.length - 1;
    double sumTr = 0, maxH = candles[last].high, minL = candles[last].low;
    for (int j = last - period + 1; j <= last; j++) {
      sumTr += tr[j];
      if (candles[j].high > maxH) maxH = candles[j].high;
      if (candles[j].low < minL) minL = candles[j].low;
    }
    final range = maxH - minL;
    if (range <= 0 || sumTr <= 0) return 50;
    return 100 * log(sumTr / range) / log(period);
  }

  double _calcDailyAtr(List<Candle> candles, int period) {
    if (candles.length < 2) return 0;
    final tr = <double>[];
    tr.add(candles[0].high - candles[0].low);
    for (int i = 1; i < candles.length; i++) {
      final hl = candles[i].high - candles[i].low;
      final hc = (candles[i].high - candles[i - 1].close).abs();
      final lc = (candles[i].low - candles[i - 1].close).abs();
      tr.add([hl, hc, lc].reduce((a, b) => a > b ? a : b));
    }
    if (tr.length < period) return 0;
    double sum = 0;
    for (int i = tr.length - period; i < tr.length; i++) sum += tr[i];
    return sum / period;
  }

  double _tickSize(double avgPrice) {
    if (avgPrice >= 100000) return 100;
    if (avgPrice >= 10000) return 50;
    if (avgPrice >= 5000) return 10;
    return 5;
  }
}
