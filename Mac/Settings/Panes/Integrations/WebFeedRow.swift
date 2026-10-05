import Hanami
import SwiftUI

struct WebFeedRow: View {

    let feed: Feed
    let onEdit: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FeedIconView(feed: feed, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .lineLimit(1)
                Text(feed.siteURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(String(localized: "FeedEdit.EditRecipe", table: "Petal"),
                   systemImage: "wand.and.stars", action: onEdit)
            Button(String(localized: "Manage.Export", table: "Petal"),
                   systemImage: "square.and.arrow.up", action: onExport)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.vertical, 2)
    }
}
