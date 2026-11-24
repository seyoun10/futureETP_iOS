import Foundation

/// C-b 커브 차트 좌표 계산(순수 함수). 확대·이동이 없어 Canvas에 바로 그린다 (RN `charts/curveLayout.ts`).
/// 눈금은 `AxisTicks.linear`·`AxisTicks.decimals`를 같이 쓴다
enum CurveLayout {
  /// 라벨이 겹치지 않게 몇 개마다 하나씩 그릴지(1 = 모두)
  static func labelStride(slotWidth: Double, labelWidth: Double) -> Int {
    slotWidth <= 0 ? 1 : max(1, Int((labelWidth / slotWidth).rounded(.up)))
  }

  /// x에 가장 가까운 칸 순번. 그림 영역 밖이면 양끝 칸(십자선을 끌 때). 칸이 없으면 nil
  static func nearestSlot(x: Double, left: Double, slotWidth: Double, count: Int) -> Int? {
    guard slotWidth > 0, count > 0 else { return nil }
    return min(max(Int(((x - left) / slotWidth).rounded(.down)), 0), count - 1)
  }

  /// 커브 선분 하나
  struct Segment: Equatable {
    var x0: Double
    var y0: Double
    var x1: Double
    var y1: Double
  }

  /// 선분이 [left, right] × [top, bottom] 상자를 지나는지
  static func segmentHitsBox(
    _ s: Segment, left: Double, right: Double, top: Double, bottom: Double
  ) -> Bool {
    let a = max(min(s.x0, s.x1), left)
    let b = min(max(s.x0, s.x1), right)
    guard a <= b else { return false }
    let ys: [Double]
    if s.x1 == s.x0 {
      ys = [s.y0, s.y1]
    } else {
      let at = { (x: Double) in s.y0 + (s.y1 - s.y0) * (x - s.x0) / (s.x1 - s.x0) }
      ys = [at(a), at(b)]
    }
    return ys.max()! >= top && ys.min()! <= bottom
  }

  /// 점 위 변화율 라벨 하나. `x`는 글자 왼쪽(점 가운데 기준), `anchor`는 점 x, `top`·`bottom`은 그 칸 점들의 가장 위·아래 y.
  /// `below`면 점 아래에 둔다(하락)
  struct PctLabel: Equatable {
    var x: Double
    var anchor: Double
    var width: Double
    var top: Double
    var bottom: Double
    var below = false
  }

  /// 글자 왼쪽 x와 기준선 y
  struct Position: Equatable {
    var x: Double
    var y: Double
  }

  /// 변화율 라벨을 모두 그리되 겹치지 않게 놓는다. 오르면 점 위, 내리면(`below`) 점 아래에만 둔다.
  /// 앞 라벨부터 놓고, 이미 놓은 라벨과 겹치면 그 라벨 바깥(위쪽 라벨은 더 위, 아래쪽 라벨은 더 아래)으로 밀어낸다.
  /// 밀려서 [minY, maxY]를 벗어나면 그 끝에 붙인다. 그 높이에서 선과 겹치면 좌우로 가장 덜 밀어 선·라벨과 겹치지 않는
  /// 자리로 옮긴다. 점 x가 글자 폭 안에 남고 [minX, maxX]를 넘지 않는 만큼만 밀고, 그런 자리가 없으면 그대로 둔다
  static func placePctLabels(
    _ labels: [PctLabel], height: Double, gap: Double, minY: Double, maxY: Double,
    minX: Double = -.infinity, maxX: Double = .infinity, segments: [Segment] = []
  ) -> [Position] {
    var placed: [(left: Double, right: Double, y: Double)] = []
    func hitsLabel(_ x: Double, _ width: Double, _ y: Double) -> (
      left: Double, right: Double, y: Double
    )? {
      placed.first { p in
        x < p.right + gap && p.left < x + width + gap && y > p.y - height && p.y > y - height
      }
    }
    func hitsLine(_ x: Double, _ width: Double, _ y: Double) -> Bool {
      segments.contains {
        segmentHitsBox($0, left: x, right: x + width, top: y - height, bottom: y)
      }
    }
    return labels.map { l in
      var y = l.below ? l.bottom + gap + height : l.top - gap
      // 밀 때마다 y가 한쪽으로만 움직여 놓은 라벨 수만큼 안에 끝난다
      while let hit = hitsLabel(l.x, l.width, y) {
        y = l.below ? hit.y + height + gap : hit.y - height - gap
      }
      y = min(max(y, minY + height), maxY)
      var x = l.x
      if hitsLine(x, l.width, y) {
        let lo = max(l.anchor - l.width, minX)
        let hi = min(l.anchor, maxX - l.width)
        // 1pt씩 오른쪽·왼쪽을 번갈아 본다
        var d = 1.0
        while l.x - d >= lo || l.x + d <= hi {
          let found = [l.x + d, l.x - d].first { c in
            c >= lo && c <= hi && !hitsLine(c, l.width, y) && hitsLabel(c, l.width, y) == nil
          }
          if let found {
            x = found
            break
          }
          d += 1
        }
      }
      placed.append((x, x + l.width, y))
      return Position(x: x, y: y)
    }
  }
}
