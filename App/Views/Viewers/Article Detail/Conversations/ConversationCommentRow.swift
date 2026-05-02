import SwiftUI

struct ConversationCommentRow: View {

    @Environment(\.openURL) private var openURL

    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Group {
                    Text(comment.author.isEmpty
                         ? String(localized: "Conversations.UnknownAuthor", table: "Articles")
                         : comment.author)
                    .fontWeight(.semibold)
                    if let date = comment.createdDate {
                        Text("·")
                            .foregroundStyle(.secondary)
                        RelativeTimeText(date: date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
            }

            SelectableText(
                comment.body,
                font: .preferredFont(forTextStyle: .subheadline),
                onLinkTap: { openURL($0) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
