import SwiftUI

struct ContentTableView: View {

    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                if !header.isEmpty {
                    row(header, isHeader: true)
                    Divider()
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    row(cells, isHeader: false)
                    if index != rows.count - 1 {
                        Divider()
                    }
                }
            }
            .background(.quinary, in: .rect(cornerRadius: 8))
        }
    }

    private func row(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
                    .frame(minWidth: 90, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
        }
    }
}
