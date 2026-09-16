import SwiftUI
import Hanami

struct BookmarkTagsSection: View {

    @Environment(FeedManager.self) private var feedManager

    @State private var tagsInUse: [(tag: BookmarkTag, count: Int)] = []
    @State private var tagBeingRenamed: BookmarkTag?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !tagsInUse.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Tags.Header", table: "Articles"))
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(tagsInUse, id: \.tag.id) { entry in
                                tagLink(entry.tag, count: entry.count)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
        }
        .sheet(item: $tagBeingRenamed) { tag in
            BookmarkTagRenameSheet(tag: tag)
                .environment(feedManager)
                .presentationDetents([.height(220)])
        }
        .task(id: feedManager.dataRevision) {
            tagsInUse = feedManager.bookmarkTagsInUse()
        }
    }

    private func tagLink(_ tag: BookmarkTag, count: Int) -> some View {
        NavigationLink(value: tag) {
            BookmarkTagChip(tag: tag, count: count)
        }
        .buttonStyle(.plain)
        .id(tag.id)
        .contextMenu {
            Button {
                tagBeingRenamed = tag
            } label: {
                Label(String(localized: "TagMenu.Rename", table: "Articles"), systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                withAnimation(.smooth.speed(2.0)) {
                    feedManager.deleteBookmarkTag(tag)
                }
            } label: {
                Label(String(localized: "TagMenu.Delete", table: "Articles"), systemImage: "trash")
            }
        }
    }
}
