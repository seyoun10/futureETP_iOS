import Core
import Foundation
import Testing

/// 테스트 번들에 앱 카탈로그(Localizable.xcstrings)를 넣어 실제 문구로 본다
private final class BundleToken {}
private let bundle = Bundle(for: BundleToken.self)
private let ko = Locale(identifier: "ko_KR")
private let en = Locale(identifier: "en_US")
private let utc = TimeZone(identifier: "UTC")!

@Suite struct L10nTests {
  @Test func fillReplacesNamedPlaceholders() {
    #expect(L10n.fill("{{time}} 기준", ["time": "10/22 09:00"]) == "10/22 09:00 기준")
    #expect(L10n.fill("{{a}}-{{b}}-{{a}}", ["a": "1", "b": "2"]) == "1-2-1")
  }

  @Test func fillKeepsUnknownPlaceholders() {
    #expect(L10n.fill("{{x}} {{y}}", ["x": "1"]) == "1 {{y}}")
  }

  @Test func stringLooksUpTheLocaleLanguage() {
    #expect(L10n.string("common.retry", locale: ko, bundle: bundle) == "다시 시도")
    #expect(L10n.string("common.retry", locale: en, bundle: bundle) == "Retry")
    // 한국어가 아니면 영어 (D-033)
    #expect(
      L10n.string("common.retry", locale: Locale(identifier: "ja_JP"), bundle: bundle) == "Retry")
  }

  @Test func errorTextKeyFallsBackToInternal() {
    struct Other: Error {}
    #expect(AppError.textKey(for: AppError(.timeout)) == "errors.TIMEOUT")
    #expect(AppError.textKey(for: Other()) == "errors.INTERNAL")
  }
}

// RN `components/FreshnessLine.test.tsx`와 같은 기대값
@Suite struct FreshnessLineTests {
  let freshness = Freshness(
    asOf: Date(timeIntervalSince1970: 1_792_677_600),  // 2026-10-22T14:00:00Z
    tradeDate: LocalDate(year: 2026, month: 10, day: 22)!,
    delayed: true, marketState: .open, nextUpdateAt: nil)

  @Test func showsAsOfTradeDateDelayAndMarketState() {
    #expect(
      FreshnessLine.text(.market(freshness), locale: ko, bundle: bundle, timeZone: utc)
        == "10/22 14:00 기준 · 거래일 10/22 · 지연 · 장중")
  }

  @Test func omitsDelayWhenNotDelayed() {
    let time = FooterTime.market(
      Freshness(
        asOf: freshness.asOf, tradeDate: freshness.tradeDate, delayed: false,
        marketState: .settlementPending, nextUpdateAt: nil))
    #expect(
      FreshnessLine.text(time, locale: ko, bundle: bundle, timeZone: utc)
        == "10/22 14:00 기준 · 거래일 10/22 · 정산 대기")
  }

  @Test func switchesToEnglish() {
    let time = FooterTime.market(
      Freshness(
        asOf: freshness.asOf, tradeDate: freshness.tradeDate, delayed: true,
        marketState: .closed, nextUpdateAt: nil))
    #expect(
      FreshnessLine.text(time, locale: en, bundle: bundle, timeZone: utc)
        == "As of 10/22 14:00 · Trade date 10/22 · Delayed · Closed")
  }

  @Test func asOfOnlyShowsTheTime() {
    #expect(
      FreshnessLine.text(.asOf(freshness.asOf), locale: ko, bundle: bundle, timeZone: utc)
        == "10/22 14:00 기준")
  }
}

@Suite struct QueryStatePhaseTests {
  @Test func dataWinsEvenAfterAFailedRefresh() {
    let state = QueryState(data: 1, error: AppError(.network))
    guard case .content(1) = state.phase else {
      Issue.record("expected content, got \(state.phase)")
      return
    }
  }

  @Test func failureWithoutDataShowsTheError() {
    let state = QueryState<Int>(error: AppError(.timeout))
    guard case .failed(let error) = state.phase else {
      Issue.record("expected failed, got \(state.phase)")
      return
    }
    #expect(error.code == .timeout)
  }

  @Test func retryingAfterFailureShowsLoading() {
    let states = [
      QueryState<Int>(), QueryState<Int>(isFetching: true),
      QueryState<Int>(error: AppError(.timeout), isFetching: true),
    ]
    for state in states {
      guard case .loading = state.phase else {
        Issue.record("expected loading, got \(state.phase)")
        return
      }
    }
  }
}
