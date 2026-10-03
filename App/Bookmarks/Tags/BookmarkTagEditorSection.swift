import SwiftUI
import Hanami

struct BookmarkTagEditorSection: View {

    @Environment(FeedManager.self) private var feedManager

    let article: Article

    @State private var appliedTags: [BookmarkTag] = []
    @State private var newTagName = ""

    private var suggestions: [String] {
        let applied = Set(appliedTags.map { BookmarkTag.normalized($0.name) })
        let fromContent = BookmarkAutoTagger.suggestedTags(title: article.title, url: article.url)
        let fromLibrary = feedManager.bookmarkTagsInUse().map(\.tag.name)
        var seen = Set<String>()
        return (fromContent + fromLibrary).filter { candidate in
            let normalized = BookmarkTag.normalized(candidate)
            guard !applied.contains(normalized) else { return false }
            return seen.insert(normalized).inserted
        }
        .prefix(6)
        .map { $0 }
    }

    var body: some View {
        Section {
            if appliedTags.isEmpty {
                Text(String(localized: "BookmarkDetail.Tags.Empty", table: "Articles"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appliedTags) { tag in
                    appliedTagRow(tag)
                }
            }

            HStack {
                TextField(String(localized: "BookmarkDetail.Tags.Add", table: "Articles"),
                          text: $newTagName)
                    .onSubmit(commitNewTag)
                Button(action: commitNewTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !suggestions.isEmpty {
                suggestionRow
            }
        } header: {
            Text(String(localized: "BookmarkDetail.Tags.Header", table: "Articles"))
        } footer: {
            Text(String(localized: "BookmarkDetail.Tags.Footer", table: "Articles"))
        }
        .task(id: feedManager.dataRevision) {
            appliedTags = feedManager.bookmarkTags(forArticleID: article.id)
        }
    }

    private func appliedTagRow(_ tag: BookmarkTag) -> some View {
        HStack {
            BookmarkTagChip(tag: tag)
            Spacer()
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    feedManager.removeBookmarkTag(tag, fromArticleID: article.id)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "BookmarkDetail.Tags.Remove", table: "Articles"))
        }
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.addBookmarkTag(named: suggestion, toArticleID: article.id)
                        }
                    } label: {
                        Label(suggestion, systemImage: "plus")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.quinary, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets())
    }

    private func commitNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.smooth.speed(2.0)) {
            feedManager.addBookmarkTag(named: trimmed, toArticleID: article.id)
        }
        newTagName = ""
    }
}
