import SwiftUI

struct TableBlockView: View {

    let header: [String]
    let rows: [[String]]

    private var columnCount: Int {
        let rowMax = rows.map(\.count).max() ?? 0
        return max(header.count, rowMax)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                if !header.isEmpty {
                    gridRow(header, isHeader: true, background: .clear)
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    let background: Color = index.isMultiple(of: 2)
                        ? .clear
                        : .secondary.opacity(0.06)
                    gridRow(row, isHeader: false, background: background)
                    if index < rows.count - 1 {
                        Divider().gridCellUnsizedAxes(.horizontal)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.55), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func gridRow(_ cells: [String], isHeader: Bool, background: Color) -> some View {
        GridRow {
            ForEach(0..<columnCount, id: \.self) { index in
                let cell = index < cells.count ? cells[index] : ""
                Text(cell)
                    .font(isHeader ? .callout.bold() : .callout)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(background)
            }
        }
    }
}
