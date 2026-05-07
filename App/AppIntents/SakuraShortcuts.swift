import AppIntents

struct SakuraShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetLatestContentIntent(),
            phrases: [
                "Get latest content from \(.applicationName)",
                "What's new in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("GetLatestContent.ShortTitle", table: "AppIntents"),
            systemImageName: "newspaper"
        )
        AppShortcut(
            intent: SearchContentIntent(),
            phrases: [
                "Search \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("SearchContent.ShortTitle", table: "AppIntents"),
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: GetTopicsAndPeopleIntent(),
            phrases: [
                "Show topics and people in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("GetTopicsAndPeople.ShortTitle", table: "AppIntents"),
            systemImageName: "person.2"
        )
        AppShortcut(
            intent: RefreshFeedsIntent(),
            phrases: [
                "Refresh \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("RefreshFeeds.ShortTitle", table: "AppIntents"),
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: AddFeedFromURLIntent(),
            phrases: [
                "Add feed to \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("AddFeedFromURL.ShortTitle", table: "AppIntents"),
            systemImageName: "plus.rectangle.on.folder"
        )
        AppShortcut(
            intent: GetOPMLIntent(),
            phrases: [
                "Export \(.applicationName) feeds as OPML"
            ],
            shortTitle: LocalizedStringResource("GetOPML.ShortTitle", table: "AppIntents"),
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: AddToBookmarksIntent(),
            phrases: [
                "Bookmark in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("AddToBookmarks.ShortTitle", table: "AppIntents"),
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: GetContentTextIntent(),
            phrases: [
                "Get text in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("GetContentText.ShortTitle", table: "AppIntents"),
            systemImageName: "text.alignleft"
        )
    }
}
