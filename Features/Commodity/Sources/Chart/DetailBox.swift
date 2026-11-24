import Core
import SwiftUI

/// 상세 박스 한 줄. 한 칸이거나, 시·고처럼 반씩 나눈 두 칸이다 (RN `charts/DetailBox.tsx`)
enum DetailRow: Equatable {
  /// 이름은 왼쪽, 값은 오른쪽 정렬. 값이 없으면 이름만
  struct Cell: Equatable {
    var label: String
    var value: String?
    var color: Color = Theme.Colors.text
  }

  case single(Cell)
  case pair(Cell, Cell)
}

/// 십자선·툴팁 상세 박스(C-a·C-b·C-c 공용). 너비는 가장 긴 줄에 맞춘다
struct DetailBox: View {
  let rows: [DetailRow]

  var body: some View {
    // 두 칸 줄은 이름·값·이름·값 4열로 맞추고, 한 칸 줄은 4열을 다 쓴다
    Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.md, verticalSpacing: 2) {
      ForEach(rows.indices, id: \.self) { i in
        switch rows[i] {
        case .single(let cell):
          GridRow {
            HStack(spacing: Theme.Spacing.md) {
              Text(verbatim: cell.label)
              Spacer(minLength: 0)
              if let value = cell.value { Text(verbatim: value) }
            }
            .foregroundStyle(cell.color)
            .gridCellColumns(4)
          }
        case .pair(let left, let right):
          GridRow {
            pairCells(left)
            pairCells(right)
          }
        }
      }
    }
    .font(.system(size: Theme.FontSize.caption).monospacedDigit())
    .lineLimit(1)
    .fixedSize()
    .padding(Theme.Spacing.sm)
    .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.xs))
  }

  @ViewBuilder private func pairCells(_ cell: DetailRow.Cell) -> some View {
    Text(verbatim: cell.label).foregroundStyle(cell.color)
    Text(verbatim: cell.value ?? "").foregroundStyle(cell.color)
      .gridColumnAlignment(.trailing)
  }
}

/// 상세 박스를 차트 네 귀퉁이 중 봉·선을 가장 적게 가리는 곳에 둔다(C-a·C-c 공용, RN `useDetailPlacement`).
/// 처음 잰 크기로 귀퉁이를 고르고, 재기 전에는 감춘다
struct PlacedDetailBox: View {
  let rows: [DetailRow]
  let index: Int
  let series: CandleSeries
  let viewport: CandleViewport
  /// 봉을 그리는 영역(y축·x축 라벨 자리를 뺀 차트 영역)
  let plot: CGSize
  /// 위쪽 정보 줄 높이. 박스는 그 아래에 둔다
  let insetTop: Double
  @State private var boxSize: CGSize?

  var body: some View {
    let box = DetailBox(rows: rows)
      .onGeometryChange(for: CGSize.self, of: \.size) { boxSize = $0 }
    if let boxSize, let rect = rect(box: boxSize) {
      box.offset(x: rect.minX, y: rect.minY)
    } else {
      box.hidden()
    }
  }

  private func rect(box: CGSize) -> CGRect? {
    guard let scale = PriceScale(series: series, indices: viewport.visibleIndices) else {
      return nil
    }
    let area = CGRect(
      x: 0, y: insetTop, width: plot.width, height: max(plot.height - insetTop, 0)
    ).insetBy(dx: Theme.Spacing.sm, dy: Theme.Spacing.sm)
    let corner = DetailCorner.leastCovered(
      area: area, box: box, crosshairX: viewport.centerX(ofBar: index, width: plot.width)
    ) { x0, x1 in
      series.markSpans(
        x0: x0, x1: x1, viewport: viewport, scale: scale, size: plot, insetTop: insetTop)
    }
    return corner.rect(in: area, box: box)
  }
}
