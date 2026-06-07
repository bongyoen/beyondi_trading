/// VWAP + 거래량 프로파일 기반 매매 신호.
enum TradeSignal {
  /// 현재가 < VWAP && 현재가 < POC → 강한 매수
  strongBuy,

  /// 현재가 > VWAP && 현재가 > POC → 강한 매도
  strongSell,

  /// 그 외 → 중립 (신호 없음)
  neutral,
}
