import TipKit

/// One-time tip pointing to the Bookmarks entry when at least one bookmark exists.
struct BookmarksSectionTip: Tip {

    @Parameter
    static var bookmarkCount: Int = 0

    var title: Text {
        Text(String(localized: "Tip.BookmarksSection.Title", table: "Onboarding"))
    }

    var message: Text? {
        Text(String(localized: "Tip.BookmarksSection.Message", table: "Onboarding"))
    }

    var image: Image? {
        Image(systemName: "bookmark")
    }

    var rules: [Rule] {
        #Rule(Self.$bookmarkCount) { $0 >= 1 }
    }

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }
}
