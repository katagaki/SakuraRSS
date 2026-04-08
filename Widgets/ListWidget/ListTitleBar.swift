import AppIntents
import SwiftUI

struct ListTitleBar: View {
    let title: String
    let listID: Int64
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if totalPages > 1 {
                HStack(spacing: 12) {
                    Button(intent: ListWidgetPageIntent(listID: listID, page: currentPage - 1)) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(currentPage > 0 ? .primary : .quaternary)
                    }
                    .disabled(currentPage <= 0)
                    .tint(.accent)

                    Text("\(currentPage + 1)/\(totalPages)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button(intent: ListWidgetPageIntent(listID: listID, page: currentPage + 1)) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(currentPage < totalPages - 1 ? .primary : .quaternary)
                    }
                    .disabled(currentPage >= totalPages - 1)
                    .tint(.accent)
                }
            }
        }
    }
}
