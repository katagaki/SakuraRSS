import SwiftUI

/// Stackless bookmarks view used inside a parent `NavigationStack`
/// (the Home tab and the iPad sidebar detail column).
struct BookmarksContentView: View {

    @Environment(FeedManager.self) var feedManager

    @State private var bookmarkedArticles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle
    @State private var showingDeleteReadAlert = false

    private var hasImages: Bool {
        bookmarkedArticles.contains { $0.imageURL != nil }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        Group {
            if bookmarkedArticles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Bookmarks.Empty.Title", table: "Articles"),
                          systemImage: "bookmark")
                } description: {
                    Text(String(localized: "Bookmarks.Empty.Description", table: "Articles"))
                }
            } else {
                DisplayStyleContentView(
                    style: effectiveStyle,
                    articles: bookmarkedArticles
                )
            }
        }
        .navigationTitle("Tabs.Bookmarks")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .toolbar {
            if !bookmarkedArticles.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingDeleteReadAlert = true
                    } label: {
                        Image(systemName: "bookmark.slash")
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: bookmarkedArticles)
        .alert(String(localized: "Bookmarks.DeleteAllRead", table: "Articles"), isPresented: $showingDeleteReadAlert) {
            Button(String(localized: "Bookmarks.DeleteAllRead.Confirm", table: "Articles"), role: .destructive) {
                try? DatabaseManager.shared.removeReadBookmarks()
                bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "Bookmarks.DeleteAllRead.Message", table: "Articles"))
        }
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.DefaultBookmarksStyle")
        }
        .onAppear {
            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
        }
        .onChange(of: feedManager.dataRevision) {
            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
        }
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
}
