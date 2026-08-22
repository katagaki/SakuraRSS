import Hanami
import SwiftUI

struct ArticleReadMenuButton: View {

    enum LabelStyle {
        case readUnread
        case playedUnplayed
    }

    @Environment(FeedManager.self) private var feedManager
    let article: Article
    var labelStyle: LabelStyle = .readUnread

    var body: some View {
        let isRead = feedManager.isRead(article)
        Button {
            feedManager.toggleRead(article)
        } label: {
            Label(title, systemImage: systemImage(isRead: isRead))
        }
    }

    private var title: String {
        let isRead = feedManager.isRead(article)
        switch labelStyle {
        case .readUnread:
            return isRead
                ? String(localized: "Article.MarkUnread", table: "Articles")
                : String(localized: "Article.MarkRead", table: "Articles")
        case .playedUnplayed:
            return isRead
                ? String(localized: "Article.MarkUnplayed", table: "Articles")
                : String(localized: "Article.MarkPlayed", table: "Articles")
        }
    }

    private func systemImage(isRead: Bool) -> String {
        switch labelStyle {
        case .readUnread:
            return isRead ? "envelope" : "envelope.open"
        case .playedUnplayed:
            return isRead ? "arrow.uturn.backward" : "checkmark"
        }
    }
}
