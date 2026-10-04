import Hanami
import SwiftUI

/// Mirrors iOS's Today: the greeting, shortcuts and recent content, then rows
/// of cards. Wide windows split them into two columns, as iPad does.
struct TodayPage: View {

    let feedManager: FeedManager
    let actions: TodayActions
    @State private var model = TodayModel()
    @State private var isWide = false

    var body: some View {
        Group {
            if isWide {
                wideLayout
            } else {
                narrowLayout
            }
        }
        // Measured rather than left to `ViewThatFits`: the card rows' ideal
        // width is every card side by side, so the wide layout never fits.
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width >= 1000
        } action: { isWide in
            self.isWide = isWide
        }
        .task(id: feedManager.dataRevision) {
            await model.load(feeds: feedManager.feeds)
        }
    }

    private var wideLayout: some View {
        HStack(spacing: 0) {
            ScrollView {
                leadingContent(isCompact: true)
                    .padding(24)
            }
            .frame(width: 400)
            .background(.ultraThinMaterial)
            ScrollView {
                TodayCardSections(model: model, feedManager: feedManager, actions: actions)
                    .padding(.vertical, 24)
            }
        }
    }

    private var narrowLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                leadingContent(isCompact: false)
                    .padding(.horizontal, 24)
                Divider()
                    .padding(.horizontal, 24)
                TodayCardSections(model: model, feedManager: feedManager, actions: actions)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func leadingContent(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            TodayHeader(isCompact: isCompact)
            TodayShortcutsGrid(feedManager: feedManager, actions: actions)
            TodayRecentContentSection(feedManager: feedManager, actions: actions)
        }
    }
}
