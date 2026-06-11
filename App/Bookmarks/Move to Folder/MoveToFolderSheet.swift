import SwiftUI
import Hanami

struct MoveToFolderSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss
    let article: Article

    private var destinationFolders: [BookmarkFolder] {
        let currentFolderID = feedManager.bookmarkFolderID(forArticleID: article.id)
        return feedManager.bookmarkFolders.filter { $0.id != currentFolderID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let folders = destinationFolders
                if !folders.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(folders) { folder in
                            folderRow(folder)
                            if folder.id != folders.last?.id {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(.fill.tertiary)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(16)
                }
            }
            .navigationTitle(String(localized: "Article.MoveToFolder", table: "Articles"))
            .navigationBarTitleDisplayMode(.inline)
            .compatibleSoftScrollEdgeEffectStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func folderRow(_ folder: BookmarkFolder) -> some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                feedManager.moveBookmark(articleID: article.id, to: folder)
            }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                BorderedIcon(
                    systemImage: folder.icon,
                    background: ListIcon.gradient(forRawValue: folder.icon),
                    size: 36,
                    iconSizeFactor: 0.5,
                    cornerRadius: 8
                )
                Text(folder.name)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
