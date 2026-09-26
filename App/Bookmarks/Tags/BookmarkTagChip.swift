import SwiftUI
import Hanami

struct BookmarkTagChip: View {

    let tag: BookmarkTag
    var count: Int?

    var body: some View {
        HStack(spacing: 5) {
            if tag.isAutomatic {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(tag.name)
                .font(.caption.weight(.medium))
            if let count {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quinary, in: .capsule)
        .foregroundStyle(.primary)
    }
}
