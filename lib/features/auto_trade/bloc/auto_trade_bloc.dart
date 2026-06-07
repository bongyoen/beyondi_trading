import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/kis_stock_api.dart';
import '../../../shared/api/api_logger.dart';
import '../model/dto/auto_trade_item.dart';
import 'auto_trade_event.dart';
import 'auto_trade_state.dart';

class AutoTradeBloc extends Bloc<AutoTradeEvent, AutoTradeState> {
  KisStockApi? _mockApi, _realApi;
  String? _mockAccountNo, _realAccountNo;
  String? _mockProductCode, _realProductCode;
  Timer? _priceTimer;
  Timer? _sellTimer;

  KisStockApi? get _api => state.isPaper ? _mockApi : _realApi;
  String? get _accountNo => state.isPaper ? _mockAccountNo : _realAccountNo;
  String? get _productCode => state.isPaper ? _mockProductCode : _realProductCode;

  AutoTradeBloc() : super(const AutoTradeState()) {
    on<LoadItems>(_onLoadItems);
    on<AddItem>(_onAddItem);
    on<RemoveItem>(_onRemoveItem);
    on<UpdateAmount>(_onUpdateAmount);
    on<SetMode>(_onSetMode);
    on<ItemStart>(_onItemStart);
    on<ItemStop>(_onItemStop);
    on<ItemPause>(_onItemPause);
    on<BatchStart>(_onBatchStart);
    on<BatchStop>(_onBatchStop);
    on<CheckSellTime>(_onCheckSellTime);
    on<RefreshPrices>(_onRefreshPrices);
    on<FetchBalance>(_onFetchBalance);
  }

  void setApi(KisStockApi api, {String? accountNo, String? productCode, bool? isMock}) {
    if (isMock ?? true) {
      _mockApi = api; _mockAccountNo = accountNo; _mockProductCode = productCode;
    } else {
      _realApi = api; _realAccountNo = accountNo; _realProductCode = productCode;
    }
  }

  String get _dir =>
      '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';

  File get _file => File('$_dir\\auto_trade_items.json');

  void startTimers() {
    _priceTimer = Timer.periodic(const Duration(seconds: 60), (_) => add(const RefreshPrices()));
    _sellTimer = Timer.periodic(const Duration(seconds: 30), (_) => add(const CheckSellTime()));
  }

  void stopTimers() {
    _priceTimer?.cancel();
    _sellTimer?.cancel();
  }

  // ---- 파일 I/O ----

  Future<void> _onLoadItems(LoadItems event, Emitter<AutoTradeState> emit) async {
    await ApiLogger.log(module: 'AUTO', method: 'LOAD', url: 'auto_trade_items.json',
        summary: '목록 로드 시작');
    try {
      if (!await _file.exists()) {
        emit(state.copyWith(isInitialized: true));
        return;
      }
      final raw = await _file.readAsString();
      final data = jsonDecode(raw) as List<dynamic>;
      final items = data.map((e) => AutoTradeItem.fromJson(e as Map<String, dynamic>)).toList();
      await ApiLogger.log(module: 'AUTO', method: 'LOAD', url: 'auto_trade_items.json',
          summary: '${items.length}개 로드 완료');
      emit(state.copyWith(items: items, isInitialized: true));
      add(const FetchBalance());
    } catch (e) {
      await ApiLogger.log(module: 'AUTO', method: 'LOAD', url: 'auto_trade_items.json',
          error: e.toString());
      emit(state.copyWith(isInitialized: true));
    }
  }

  void _saveItems(List<AutoTradeItem> items) {
    try {
      final json = items.map((e) => e.toJson()).toList();
      _file.writeAsStringSync(jsonEncode(json));
    } catch (_) {}
  }

  // ---- 종목 관리 ----

  Future<void> _onAddItem(AddItem event, Emitter<AutoTradeState> emit) async {
    if (state.items.length >= 10) return;
    if (state.items.any((i) => i.code == event.code)) return;
    final items = [...state.items, AutoTradeItem(code: event.code, name: event.name)];
    _saveItems(items);
    emit(state.copyWith(items: items));
  }

  Future<void> _onRemoveItem(RemoveItem event, Emitter<AutoTradeState> emit) async {
    final target = state.items.firstWhere((i) => i.code == event.code,
        orElse: () => AutoTradeItem(code: '', name: ''));
    if (target.code.isEmpty) return;
    if (target.status == TradeStatus.running) {
      await _sell(target);
    }
    final items = state.items.where((i) => i.code != event.code).toList();
    _saveItems(items);
    emit(state.copyWith(items: items));
  }

  Future<void> _onUpdateAmount(UpdateAmount event, Emitter<AutoTradeState> emit) async {
    final items = state.items.map((i) {
      if (i.code != event.code) return i;
      return i.copyWith(allocatedAmount: event.amount);
    }).toList();
    _saveItems(items);
    emit(state.copyWith(items: items));
  }

  Future<void> _onSetMode(SetMode event, Emitter<AutoTradeState> emit) async {
    emit(state.copyWith(isPaper: event.isPaper));
    add(const FetchBalance());
  }

  // ---- 주문 실행 (emit-safe) ----

  Future<void> _executeOrder(AutoTradeItem item, bool isBuy, Emitter<AutoTradeState> emit) async {
    final idx = state.items.indexWhere((i) => i.code == item.code);
    if (idx < 0) return;

    if (isBuy) {
      if (item.status != TradeStatus.ready) return;
      try {
        final result = await _buy(item);
        final items = [...state.items];
        items[idx] = items[idx].copyWith(
          status: TradeStatus.running,
          entryPrice: _parsePrice(result, 'buy'),
          quantity: _parseQty(result),
          orderNo: _parseOrderNo(result),
        );
        _saveItems(items);
        emit(state.copyWith(items: items));
      } catch (e) {
        await ApiLogger.log(module: 'AUTO', method: 'BUY_FAIL', url: item.code, error: e.toString());
      }
    } else {
      if (item.status != TradeStatus.running && item.status != TradeStatus.paused) return;
      try {
        await _sell(item);
        final items = [...state.items];
        items[idx] = items[idx].copyWith(status: TradeStatus.sold, currentPrice: null);
        _saveItems(items);
        emit(state.copyWith(items: items));
      } catch (e) {
        await ApiLogger.log(module: 'AUTO', method: 'SELL_FAIL', url: item.code, error: e.toString());
      }
    }
  }

  // ---- 개별 실행/중지/일시정지 ----

  Future<void> _onItemStart(ItemStart event, Emitter<AutoTradeState> emit) async {
    final idx = state.items.indexWhere((i) => i.code == event.code);
    if (idx < 0 || state.items[idx].status != TradeStatus.ready) return;
    await _executeOrder(state.items[idx], true, emit);
  }

  Future<void> _onItemStop(ItemStop event, Emitter<AutoTradeState> emit) async {
    final idx = state.items.indexWhere((i) => i.code == event.code);
    if (idx < 0) return;
    await _executeOrder(state.items[idx], false, emit);
  }

  Future<void> _onItemPause(ItemPause event, Emitter<AutoTradeState> emit) async {
    final idx = state.items.indexWhere((i) => i.code == event.code);
    if (idx < 0) return;
    final cur = state.items[idx];
    if (cur.status != TradeStatus.running) return;
    final items = [...state.items];
    items[idx] = cur.copyWith(status: TradeStatus.paused);
    _saveItems(items);
    emit(state.copyWith(items: items));
  }

  // ---- 일괄 실행/중지 ----

  Future<void> _onBatchStart(BatchStart event, Emitter<AutoTradeState> emit) async {
    final readyItems = state.items.where((i) => i.status == TradeStatus.ready).toList();
    if (readyItems.isEmpty) return;
    emit(state.copyWith(isBatchRunning: true));
    for (int i = 0; i < readyItems.length; i++) {
      await _executeOrder(readyItems[i], true, emit);
      await Future.delayed(const Duration(seconds: 1));
    }
    emit(state.copyWith(isBatchRunning: false));
  }

  Future<void> _onBatchStop(BatchStop event, Emitter<AutoTradeState> emit) async {
    final running = state.items.where((i) => i.status == TradeStatus.running).toList();
    if (running.isEmpty) return;
    emit(state.copyWith(isBatchRunning: true));
    for (int i = 0; i < running.length; i++) {
      await _executeOrder(running[i], false, emit);
      await Future.delayed(const Duration(seconds: 1));
    }
    emit(state.copyWith(isBatchRunning: false));
  }

  // ---- 자동 매도 ----

  Future<void> _onCheckSellTime(CheckSellTime event, Emitter<AutoTradeState> emit) async {
    final now = DateTime.now();
    // KST 기준 14:55 이후면 매도 준비, 15:00 이후면 전량 매도
    final kst = now.toUtc().add(const Duration(hours: 9));
    final minute = kst.hour * 60 + kst.minute;
    if (minute >= 15 * 60) {
      // 15:00 이후 → 전량 매도
      add(const BatchStop());
      stopTimers();
    }
  }

  // ---- 현재가 갱신 ----

  Future<void> _onRefreshPrices(RefreshPrices event, Emitter<AutoTradeState> emit) async {
    if (_api == null) return;
    final items = [...state.items];
    bool changed = false;
    for (int i = 0; i < items.length; i++) {
      if (items[i].status != TradeStatus.running && items[i].status != TradeStatus.paused) continue;
      try {
        final price = await _api!.inquirePrice(items[i].code);
        final currentPrice = double.tryParse(price['stck_prpr'] as String? ?? '');
        if (currentPrice != null) {
          items[i] = items[i].copyWith(currentPrice: currentPrice);
          changed = true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (changed) emit(state.copyWith(items: items));
  }

  Future<void> _onFetchBalance(FetchBalance event, Emitter<AutoTradeState> emit) async {
    if (_api == null) {
      await ApiLogger.log(module: 'AUTO', method: 'BALANCE', url: '/inquire-balance',
          summary: 'API 없음 — 잔고조회 생략');
      return;
    }
    if (_accountNo == null) {
      await ApiLogger.log(module: 'AUTO', method: 'BALANCE', url: '/inquire-balance',
          summary: '계좌번호 없음 — 잔고조회 생략');
      emit(state.copyWith(availableBalance: 0));
      return;
    }
    try {
      await ApiLogger.log(module: 'AUTO', method: 'BALANCE', url: '/inquire-balance',
          summary: '잔고조회 시작 accountNo=$_accountNo');
      final (_, summary) = await _api!.fetchBalance(
        accountNo: _accountNo!,
        productCode: _productCode!,
      );
      final raw = summary['prvs_rcdl_excc_amt'] as String? ?? '0';
      final balance = double.tryParse(raw) ?? 0.0;
      await ApiLogger.log(module: 'AUTO', method: 'BALANCE', url: '/inquire-balance',
          summary: '잔고=${balance}원');
      emit(state.copyWith(availableBalance: balance));
    } catch (e) {
      await ApiLogger.log(module: 'AUTO', method: 'BALANCE', url: '/inquire-balance',
          error: e.toString());
    }
  }

  // ---- 주문 도우미 ----

  Future<Map<String, dynamic>> _buy(AutoTradeItem item) async {
    if (_api == null) throw Exception('API 인증 정보가 없습니다. KIS 연결 후 다시 시도하세요.');
    if (_accountNo == null) throw Exception('계좌번호가 설정되지 않았습니다. KIS 연결 정보를 확인하세요.');
    if (_productCode == null) throw Exception('상품코드가 설정되지 않았습니다.');
    // 시장가 매수: orderDivision='01', price=0
    return await _api!.orderBuy(
      accountNo: _accountNo!,
      productCode: _productCode!,
      symbol: item.code,
      quantity: item.allocatedAmount > 0 && item.currentPrice != null && item.currentPrice! > 0
          ? (item.allocatedAmount / item.currentPrice!).floor().clamp(1, 999999)
          : 1,
      price: 0,
      orderDivision: '01',
    );
  }

  Future<void> _sell(AutoTradeItem item) async {
    if (_api == null || _accountNo == null || _productCode == null) {
      await ApiLogger.log(module: 'AUTO', method: 'SELL_FAIL', url: item.code,
          summary: 'API/계좌 정보 없음 — 매도 생략');
      return;
    }
    if (item.quantity == null || item.quantity! <= 0) return;
    await _api!.orderSell(
      accountNo: _accountNo!,
      productCode: _productCode!,
      symbol: item.code,
      quantity: item.quantity!,
      price: 0,
      orderDivision: '01',
    );
  }

  double? _parsePrice(Map<String, dynamic> result, String type) {
    try {
      final out = result['output'] as Map<String, dynamic>? ?? result;
      final raw = out['Ft_unpr3'] as String? ?? out['fno_unpr3'] as String? ?? '';
      return double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  int? _parseQty(Map<String, dynamic> result) {
    try {
      final out = result['output'] as Map<String, dynamic>? ?? result;
      final raw = out['ord_qty'] as String? ?? '';
      return int.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  String? _parseOrderNo(Map<String, dynamic> result) {
    try {
      final out = result['output'] as Map<String, dynamic>? ?? result;
      return out['odno'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() {
    stopTimers();
    return super.close();
  }
}
