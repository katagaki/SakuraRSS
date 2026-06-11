import SwiftUI
import Hanami

struct BookmarkFolderArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss
    let folder: BookmarkFolder

    @State private var articles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle
    @State private var hasScrolledPastTitle: Bool = false

    init(folder: BookmarkFolder) {
        self.folder = folder
        self._displayStyle = State(initialValue: Self.initialDisplayStyle(for: folder))
    }

    private static func initialDisplayStyle(for folder: BookmarkFolder) -> FeedDisplayStyle {
        if let raw = folder.displayStyle, let style = FeedDisplayStyle(rawValue: raw) {
            return style
        }
        let bookmarksRaw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        return bookmarksRaw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback
    }

    private var currentFolder: BookmarkFolder {
        feedManager.bookmarkFolders.first(where: { $0.id == folder.id }) ?? folder
    }

    private var folderExists: Bool {
        feedManager.bookmarkFolders.contains(where: { $0.id == folder.id })
    }

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages {
            return .inbox
        }
        if displayStyle == .podcast {
            return .inbox
        }
        return displayStyle
    }

    private var showsPrincipalTitle: Bool {
        !effectiveDisplayStyle.supportsRichHeader || hasScrolledPastTitle
    }

    var body: some View {
        Group {
            if articles.isEmpty {
                ScrollView {
                    BookmarkFolderHeaderView(folder: currentFolder)
                    ContentUnavailableView {
                        Label(String(localized: "Folder.Empty.Title", table: "Articles"),
                              systemImage: "bookmark")
                    } description: {
                        Text(String(localized: "Folder.Empty.Description", table: "Articles"))
                    }
                    .padding(.top, 60)
                }
            } else {
                DisplayStyleContentView(
                    style: effectiveDisplayStyle,
                    articles: articles,
                    headerView: AnyView(BookmarkFolderHeaderView(folder: currentFolder))
                )
            }
        }
        .sakuraBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                principalTitle
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    DisplayStylePicker(
                        displayStyle: $displayStyle,
                        hasImages: hasImages,
                        showCards: false
                    )
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .menuActionDismissBehavior(.disabled)
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 90
        } action: { _, scrolled in
            guard scrolled != hasScrolledPastTitle else { return }
            withAnimation(.smooth.speed(2.0)) {
                hasScrolledPastTitle = scrolled
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: articles)
        .onChange(of: displayStyle) { _, newValue in
            feedManager.updateBookmarkFolderDisplayStyle(currentFolder, displayStyle: newValue.rawValue)
        }
        .onAppear {
            reloadArticles()
        }
        .onChange(of: feedManager.dataRevision) {
            reloadArticles()
        }
        .onChange(of: folderExists) { _, exists in
            if !exists { dismiss() }
        }
    }

    @ViewBuilder
    private var principalTitle: some View {
        #if os(visionOS)
        Text(currentFolder.name)
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(height: 42)
            .opacity(showsPrincipalTitle ? 1 : 0)
            .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
        #else
        Text(currentFolder.name)
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(height: 42)
            .padding(.horizontal, 18)
            .compatibleGlassEffect(in: .capsule)
            .opacity(showsPrincipalTitle ? 1 : 0)
            .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
        #endif
    }

    private func reloadArticles() {
        articles = feedManager.bookmarkedArticles(in: currentFolder)
    }
}
