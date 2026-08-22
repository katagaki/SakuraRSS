import SwiftUI
import Hanami

struct PhotosArticleCardHeader: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article
    let feed: Feed?
    let feedName: String?
    let icon: UIImage?
    let acronymIcon: UIImage?
    let skipIconInset: Bool

    var body: some View {
        let isRead = feedManager.isRead(article)
        HStack(spacing: 10) {
            if let feed {
                NavigationLink(value: feed) {
                    HStack(spacing: 10) {
                        feedAvatarView
                        if let feedName {
                            feedNameText(feedName)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                feedAvatarView
                if let feedName {
                    feedNameText(feedName)
                }
            }

            Spacer()

            if !isRead {
                UnreadDotView(isRead: isRead)
            }

            Menu {
                Button {
                    log("PhotosCard", "Menu: toggle read for article \(article.id)")
                    feedManager.toggleRead(article)
                } label: {
                    Label(
                        isRead
                            ? String(localized: "Article.MarkUnread", table: "Articles")
                            : String(localized: "Article.MarkRead", table: "Articles"),
                        systemImage: isRead ? "envelope" : "envelope.open"
                    )
                }
                MoveToFolderMenuItems(article: article)
            } label: {
                Image(systemName: "ellipsis")
                    .tint(.primary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let icon {
            IconImage(icon, size: 32, circle: true, skipInset: skipIconInset)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 32, circle: true, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 32, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 32, height: 32)
        }
    }

    private func feedNameText(_ name: String) -> some View {
        Text(name)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}
