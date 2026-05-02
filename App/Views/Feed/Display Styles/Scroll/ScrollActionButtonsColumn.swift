import SwiftUI

struct ScrollActionButtonsColumn: View {

    let article: Article
    let icon: UIImage?
    let acronymIcon: UIImage?
    let feedName: String?
    let isVideoFeed: Bool
    let onOpenFeed: () -> Void
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onToggleBookmark: () -> Void
    let shareURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            Button(action: onOpenFeed) {
                Group {
                    if let icon {
                        IconImage(icon, size: 48, cornerRadius: 8, circle: isVideoFeed)
                    } else if let acronymIcon {
                        IconImage(acronymIcon, size: 48, cornerRadius: 8,
                                     circle: isVideoFeed, skipInset: true)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 48, circle: isVideoFeed, cornerRadius: 8)
                    } else {
                        Circle().fill(.white.opacity(0.2)).frame(width: 48, height: 48)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(feedName ?? ""))

            Button(action: onOpen) {
                labeledIcon(
                    systemName: article.isYouTubeURL ? "play.rectangle.fill" : "safari.fill",
                    label: Text(String(localized: "Article.OpenInBrowser", table: "Articles"))
                )
            }
            .accessibilityLabel(Text(String(localized: "Article.OpenInBrowser", table: "Articles")))
            .disabled(!article.hasLink)

            Button(action: onCopy) {
                labeledIcon(
                    systemName: "square.on.square.fill",
                    label: Text(String(localized: "Article.CopyLink", table: "Articles"))
                )
            }
            .accessibilityLabel(Text(String(localized: "Article.CopyLink", table: "Articles")))

            Button(action: onToggleBookmark) {
                labeledIcon(
                    systemName: article.isBookmarked ? "bookmark.fill" : "bookmark",
                    label: Text(article.isBookmarked
                                ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                : String(localized: "Article.Bookmark", table: "Articles"))
                )
            }
            .accessibilityLabel(Text(article.isBookmarked
                                     ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                     : String(localized: "Article.Bookmark", table: "Articles")))

            if let shareURL {
                ShareLink(item: shareURL) {
                    labeledIcon(
                        systemName: "square.and.arrow.up",
                        label: Text(String(localized: "Article.Share", table: "Articles")),
                        iconOffsetY: -1
                    )
                }
                .accessibilityLabel(Text(String(localized: "Article.Share", table: "Articles")))
            }
        }
        .font(.title)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
        .buttonStyle(.plain)
    }

    private func labeledIcon(
        systemName: String,
        label: Text,
        iconOffsetY: CGFloat = 0
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .offset(y: iconOffsetY)
            label
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
