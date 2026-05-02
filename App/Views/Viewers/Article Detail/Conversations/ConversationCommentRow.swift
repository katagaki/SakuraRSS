import SwiftUI

struct ConversationCommentRow: View {

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

            Text(comment.body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
