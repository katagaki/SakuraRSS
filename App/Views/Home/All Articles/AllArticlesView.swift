import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") var selectedSelection: HomeSelection = .section(.today)

    var body: some View {
        ZStack {
            if case .section(.today) = selectedSelection {
                TodayView()
                    .transition(.opacity)
            } else {
                HomeSectionView(source: contentSource)
                    .transition(.opacity)
            }
        }
        .animation(.smooth.speed(2.0), value: isShowingToday)
        .applyNavigationTitleIfNeeded(currentTitle)
        .onChange(of: availableSections) {
            validateSelection()
        }
        .onChange(of: feedManager.lists) {
            validateSelection()
        }
    }

    private var isShowingToday: Bool {
        if case .section(.today) = selectedSelection { return true }
        return false
    }

    var currentTitle: String {
        switch selectedSelection {
        case .section(let section):
            return section.localizedTitle
        case .list(let id):
            return feedManager.lists.first { $0.id == id }?.name
                ?? String(localized: "Shared.AllArticles")
        case .topic(let name):
            return name
        }
    }

    var contentSource: HomeContentSource {
        switch selectedSelection {
        case .section(.today):
            // Today tab is rendered by TodayView, but provide a stable source
            // value so callers don't crash if they read it during the switch.
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
}

private extension View {
    /// Apply a navigation title only on iPad. iPhone uses a custom Today top bar
    /// that supplies its own title and section tabs, so the system nav bar is hidden.
    @ViewBuilder
    func applyNavigationTitleIfNeeded(_ title: String) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
        } else {
            self
        }
    }
}
