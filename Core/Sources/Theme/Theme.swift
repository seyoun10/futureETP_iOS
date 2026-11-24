import SwiftUI

/// 테마 토큰(D-031). 다크 전용이라 테마 전환은 없다. 값은 RN `theme/tokens.ts`와 같고, 차트도 같은 값을 읽는다
public enum Theme {
  public enum Colors {
    public static let background = Color(hex: 0x000000)
    public static let surface = Color(hex: 0x1e1e1e)
    public static let surfaceSelected = Color(hex: 0x3a3a6a)
    public static let border = Color(hex: 0x2a2a2a)
    /// 목록 항목 사이 구분선. border보다 밝게
    public static let separator = Color(hex: 0x4a4a4a)
    /// title-bar 아래·tab-bar 위 구분선
    public static let barSeparator = Color(hex: 0xffffff)
    /// 차트 위에 겹친 정보 줄 배경(뒤의 rare-level 선·격자가 비쳐 보이게)
    public static let overlay = Color(hex: 0x000000, opacity: 0.65)
    public static let text = Color(hex: 0xe0e0e0)
    public static let textSecondary = Color(hex: 0x9e9e9e)
    /// 등락 0, 데이터 없음 등 방향이 없는 값
    public static let neutral = Color(hex: 0x9e9e9e)
    /// 모달 뒤 화면을 어둡게 가리는 배경
    public static let backdrop = Color(hex: 0x000000, opacity: 0.5)
    /// 오류 안내 문구(B-b 키 거절, B·B-a 저장 실패, rare-level 입력 오류)
    public static let error = Color(hex: 0xef5350)
    /// [⚙] 알림 꺼짐 점
    public static let badge = Color(hex: 0xef5350)
    /// 휴장 달력: 오늘 테두리(등락 색·차트 선과 따로 본다)
    public static let today = Color(hex: 0xffffff)

    /// 휴장 달력 시장별 휴장 점
    public static func market(_ market: CalendarMarket) -> Color {
      switch market {
      case .cme: Color(hex: 0xffa726)
      case .krx: Color(hex: 0x4fc3f7)
      case .nyse: Color(hex: 0x81c784)
      }
    }
  }

  public enum ChartColors {
    public static let grid = Color(hex: 0x2a2a2a)
    public static let tick = Color(hex: 0x9e9e9e)
    public static let crosshair = Color(hex: 0xffffff)
    /// 십자선 점선은 라벨 상자(흰색)보다 옅게 해 봉·선을 덜 가린다
    public static let crosshairLine = Color(hex: 0xffffff, opacity: 0.6)
    public static let crosshairText = Color(hex: 0x000000)
    /// 마지막 봉 종가 라벨·점선(흰색)과 보이는 마지막 봉 종가 라벨·점선(회색)(screens.md C-a)
    public static let lastPrice = Color(hex: 0xffffff)
    public static let currentPrice = Color(hex: 0x9e9e9e)
    /// 노랑은 이평선 전용(screens.md C-a)
    public static let movingAverage = Color(hex: 0xffd54f)
    /// rare-level 선은 레벨 값이 아니라 순위로 고른다. 0 = 가장 덜 드문 레벨(옅음) → 4 = 가장 드문 레벨(진함)
    public static let rareLevels = [0x4a3d66, 0x62508a, 0x7c62b0, 0x9a72d8, 0xb884ff].map {
      Color(hex: $0)
    }
    /// 롤 표시는 청록(이평선 노랑·rare-level 보라·등락 색과 겹치지 않음). 롤 기간 음영, 대표월물 전환일 세로 점선
    public static let rollShade = Color(hex: 0x4dd0e1, opacity: 0.12)
    public static let rollSwitch = Color(hex: 0x4dd0e1, opacity: 0.45)
    /// 보이는 구간 최고가·최저가 꼬리표
    public static let extremeTag = Color(hex: 0xe0e0e0)
    /// C-b 커브: 기준일은 흰색 실선, 비교일은 회색 점선(screens.md C-b)
    public static let curveBase = Color(hex: 0xffffff)
    public static let curveCurrent = Color(hex: 0x9e9e9e)
    /// C-c 월물 선은 만기순 순번으로 고른다. 근월물→원월물을 빨·주·노·초·파 순서로, 6번째는 대표월물 안전장치 월물(D-092)
    public static let contractLines = [0xef5350, 0xffa726, 0xffee58, 0x66bb6a, 0x42a5f5, 0x90a4ae]
      .map { Color(hex: $0) }
  }

  public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
  }

  public enum FontSize {
    public static let caption: CGFloat = 12
    public static let body: CGFloat = 14
    public static let title: CGFloat = 17
    public static let headline: CGFloat = 22
  }

  public enum Radius {
    public static let sm: CGFloat = 4
    public static let md: CGFloat = 6
  }

  public enum Size {
    /// 최소 터치 영역(Apple HIG 44pt)
    public static let touchTarget: CGFloat = 44
  }
}

extension Color {
  /// `0xRRGGBB` sRGB 값
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255,
      opacity: opacity
    )
  }
}
