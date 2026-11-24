#if DEBUG
  import Core
  import Foundation

  /// C-a 스파이크용 가짜 지수 일봉. 시드가 같으면 같은 봉이 나온다.
  /// 이평선(60일)과 rare-level 밴드 위·아래 3개씩(실제 응답의 많은 쪽)을 함께 만든다
  enum SpikeSeries {
    static func make(barCount: Int, seed: UInt64 = 42) -> CandleSeries {
      var random = SplitMix(seed: seed)
      var bars: [CandleSeries.Bar] = []
      bars.reserveCapacity(barCount)
      var close = 2_000.0
      for _ in 0..<barCount {
        let open = close * exp(random.normal() * 0.004)
        close = open * exp(random.normal() * 0.012)
        let high = max(open, close) * (1 + abs(random.normal()) * 0.005)
        let low = min(open, close) * (1 - abs(random.normal()) * 0.005)
        bars.append(.init(open: open, high: high, low: low, close: close))
      }

      let period = 60
      var ma = [Double?](repeating: nil, count: barCount)
      var sum = 0.0
      for i in 0..<barCount {
        sum += bars[i].close
        if i >= period { sum -= bars[i - period].close }
        if i >= period - 1 { ma[i] = sum / Double(period) }
      }

      let levels: [(key: String, disparity: Double, rank: Int)] = [
        ("up-1", 12, 2), ("up-5", 8, 1), ("up-10", 5, 0),
        ("down-1", -12, 2), ("down-5", -8, 1), ("down-10", -5, 0),
      ]
      let bands = levels.map { level in
        CandleSeries.Line(
          id: level.key,
          values: ma.map { $0.map { $0 * (1 + level.disparity / 100) } },
          color: Theme.ChartColors.rareLevels[level.rank], width: 1)
      }
      let average = CandleSeries.Line(
        id: "ma", values: ma, color: Theme.ChartColors.movingAverage, width: 2.5)
      return CandleSeries(bars: bars, lines: bands + [average])
    }
  }

  /// 시드 고정 난수(SplitMix64)
  private struct SplitMix {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return z ^ (z >> 31)
    }

    mutating func uniform() -> Double { Double(next() >> 11) / Double(1 << 53) }

    /// 표준 정규분포(Box-Muller)
    mutating func normal() -> Double {
      let u1 = max(uniform(), .leastNonzeroMagnitude)
      return sqrt(-2 * log(u1)) * cos(2 * .pi * uniform())
    }
  }
#endif
