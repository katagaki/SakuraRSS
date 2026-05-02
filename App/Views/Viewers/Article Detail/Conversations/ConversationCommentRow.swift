import SwiftUI

struct ConversationCommentRow: View {

    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(comment.author.isEmpty
                     ? String(localized: "Conversations.UnknownAuthor", table: "Articles")
                     : comment.author)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let date = comment.createdDate {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
