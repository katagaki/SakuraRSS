import SwiftUI
import Hanami

struct HomeContentArea: View {

    @Environment(FeedManager.self) var feedManager
    let selectionStore: HomeSelectionStore
    let tabItems: [HomeSectionBarItem]
    let usesPhoneTopBarRedesign: Bool
    let sectionDisplayMenu: HomeSectionDisplayMenuModel

    private var isTodaySelected: Bool {
        if case .section(.today) = selectionStore.selection { return true }
        return false
    }

    private var contentSource: HomeContentSource {
        switch selectionStore.selection {
        case .section(.today):
            return .section(nil)
        case .section(let section):
            return .section(section.feedSection)
        case .list(let id):
            if let list = feedManager.lists.first(where: { $0.id == id }) {
                return .list(list)
            }
            return .section(nil)
        case .topic(let name):
            return .topic(name)
        }
    }

    var body: some View {
        content
            .animation(.smooth.speed(2.0), value: isTodaySelected)
    }

    @ViewBuilder
    private var content: some View {
        if tabItems.isEmpty {
            emptyState
        } else if isTodaySelected {
            TodayView()
                .transition(.opacity)
        } else {
            HomeSectionView(source: contentSource)
                .environment(
                    \.homeSectionDisplayMenu,
                    usesPhoneTopBarRedesign ? sectionDisplayMenu : nil
                )
                .transition(.opacity)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "Home.Empty.Title", table: "Home"),
                systemImage: "rectangle.stack.badge.xmark"
            )
        } description: {
            Text(String(localized: "Home.Empty.Description", table: "Home"))
        }
    }
}
