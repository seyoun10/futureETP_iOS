import SwiftUI

/// 범례 줄 앞 선 견본(C-b·C-c 공용, RN `charts/LegendLine.tsx`). 점선도 실선과 길이가 같다
struct LegendLine: View {
  static let width: CGFloat = 18

  let color: Color
  /// 점선의 선·빈칸 길이. 없으면 실선
  var dash: [CGFloat] = []
  var lineWidth: CGFloat = 2

  var body: some View {
    Canvas { context, size in
      var path = Path()
      path.move(to: CGPoint(x: 0, y: size.height / 2))
      path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
      context.stroke(
        path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, dash: dash))
    }
    .frame(width: Self.width, height: lineWidth)
  }
}

/// 항목을 한 줄에 놓다가 넘치면 다음 줄로 넘기고, 줄마다 가운데 정렬한다 (RN `flexWrap: 'wrap'`·`justifyContent: 'center'`)
struct CenteredFlowLayout: Layout {
  var spacing: CGFloat
  var lineSpacing: CGFloat = 0

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
    let width = rows.map(\.width).max() ?? 0
    let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: proposal.width ?? width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var y = bounds.minY
    for row in rows(width: bounds.width, subviews: subviews) {
      var x = bounds.minX + (bounds.width - row.width) / 2
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
        x += size.width + spacing
      }
      y += row.height + lineSpacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let added = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      if added > width, !row.indices.isEmpty {
        rows.append(row)
        row = Row()
      }
      row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
    }
    if !row.indices.isEmpty { rows.append(row) }
    return rows
  }
}
