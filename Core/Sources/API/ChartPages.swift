import Foundation

/// 3년씩 받는 C 차트 응답 한 페이지(C-a `DisparityChart`, C-c `ContractsChart`, D-104)
public protocol ChartPage: Sendable {
  var freshness: Freshness { get }
  /// 이 페이지보다 이른 봉이 더 있는지
  var hasMore: Bool { get }
  /// 이 페이지의 가장 이른 거래일. 다음 페이지는 이 날짜보다 이른 3년이다
  var firstTradeDate: LocalDate? { get }
}

extension DisparityChart: ChartPage {
  public var firstTradeDate: LocalDate? { bars.first?.tradeDate }
}

extension ContractsChart: ChartPage {
  public var firstTradeDate: LocalDate? { dates.first }
}

/// 받은 페이지들. 최근 페이지가 앞이다(RN `InfiniteData.pages`)
public struct ChartPages<Page: ChartPage>: Sendable {
  public let pages: [Page]

  /// 페이지가 하나 이상이어야 한다
  public init(_ pages: [Page]) {
    precondition(!pages.isEmpty, "ChartPages needs a page")
    self.pages = pages
  }

  /// 최근 페이지. 봉 밖 값(freshness·기준값·rare 레벨 등)은 이것을 쓴다
  public var latest: Page { pages[0] }
  /// 가장 이른 페이지 값
  public var hasMore: Bool { pages[pages.count - 1].hasMore }
  /// 이전 3년을 받을 `before`. 더 없으면 nil
  public var nextBefore: LocalDate? { hasMore ? pages[pages.count - 1].firstTradeDate : nil }

  /// 가장 이른 페이지부터 이어 붙인다 (RN `mergeDisparityPages`)
  public func joined<Element>(_ elements: (Page) -> [Element]) -> [Element] {
    pages.reversed().flatMap(elements)
  }

  func appending(_ older: Page) -> ChartPages {
    ChartPages(pages + [older])
  }

  /// 최근 페이지부터 `pageCount`개까지(더 없으면 거기까지) 다시 받는다 (TanStack 무한 조회 refetch)
  static func refetch(
    pageCount: Int, fetchPage: @Sendable (LocalDate?) async throws -> Page
  ) async throws -> ChartPages {
    var pages = ChartPages([try await fetchPage(nil)])
    while pages.pages.count < pageCount, let before = pages.nextBefore {
      pages = pages.appending(try await fetchPage(before))
    }
    return pages
  }
}

/// 페이지 조회와 이전 3년 받기 (RN `useInfiniteQuery`의 `fetchNextPage`)
@MainActor
public struct PagedQuery<Page: ChartPage> {
  public let query: Query<ChartPages<Page>>
  let fetchPage: @Sendable (LocalDate?) async throws -> Page

  /// 더 이른 페이지가 있는지. 데이터가 없으면 false
  public var hasOlder: Bool { query.state.data?.nextBefore != nil }

  /// 이전 3년을 받아 붙인다. 더 없으면 하지 않는다. 실패면 오류를 돌려준다
  @discardableResult
  public func fetchOlder() async -> AppError? {
    guard hasOlder else { return nil }
    let fetchPage = fetchPage
    return await query.fetchMore { pages in
      guard let before = pages.nextBefore else { return pages }
      return pages.appending(try await fetchPage(before))
    }
  }
}
