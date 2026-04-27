import SwiftUI

struct ListRowView: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: list.icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.body)
                    .lineLimit(1)
                let count = feedManager.feedCount(for: list)
                Text(String(localized: "FeedCount \(count)", table: "Lists"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let unread = feedManager.unreadCount(for: list)
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tertiary)
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
    }
}
