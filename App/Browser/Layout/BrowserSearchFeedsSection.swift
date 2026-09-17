import SwiftUI
import Hanami

/// The feeds a search term names, above the articles it turns up. Capped at a
/// single row: the term is usually after an article, and the feeds are a
/// shortcut rather than the answer.
struct BrowserSearchFeedsSection: View {

    static let limit = 4

    let feeds: [Feed]

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 16),
        count: BrowserSearchFeedsSection.limit
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared.Feeds")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                ForEach(feeds) { feed in
                    NavigationLink(value: feed) {
                        FollowingFeedGridCell(feed: feed)
                    }
                    .buttonStyle(.plain)
                    .id(feed.id)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

extension Feed {

    /// How well the feed answers a search term: a name that starts with it
    /// beats one that merely contains it, which beats a domain match. Nil
    /// when the feed doesn't match at all.
    func searchRank(for query: String) -> Int? {
        if title.localizedCaseInsensitiveHasPrefix(query) { return 0 }
        if title.localizedCaseInsensitiveContains(query) { return 1 }
        if domain.localizedCaseInsensitiveContains(query) { return 2 }
        return nil
    }
}

private extension String {
    func localizedCaseInsensitiveHasPrefix(_ prefix: String) -> Bool {
        range(of: prefix, options: [.caseInsensitive, .anchored], locale: .current) != nil
    }
}
