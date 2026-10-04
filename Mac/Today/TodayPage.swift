import Hanami
import SwiftUI

/// Mirrors iOS's Today: the greeting, shortcuts and recent content, then rows
/// of cards. Wide windows split them into two columns, as iPad does.
struct TodayPage: View {

    let feedManager: FeedManager
    let actions: TodayActions
    @State private var model = TodayModel()

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
                .frame(minWidth: 860)
            narrowLayout
        }
        .task(id: feedManager.dataRevision) {
            await model.load(feeds: feedManager.feeds)
        }
    }

    private var wideLayout: some View {
        HStack(spacing: 0) {
            ScrollView {
                leadingContent
                    .padding(24)
            }
            .frame(width: 380)
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
                leadingContent
                    .padding(.horizontal, 24)
                Divider()
                    .padding(.horizontal, 24)
                TodayCardSections(model: model, feedManager: feedManager, actions: actions)
            }
            .padding(.vertical, 24)
        }
    }

    private var leadingContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            TodayHeader()
            TodayShortcutsGrid(feedManager: feedManager, actions: actions)
            TodayRecentContentSection(feedManager: feedManager, actions: actions)
        }
    }
}
