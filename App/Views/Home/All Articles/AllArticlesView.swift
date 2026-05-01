import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") var selectedSelection: HomeSelection = .section(.all)

    var body: some View {
        HomeSectionView(source: contentSource)
        .applyNavigationTitleIfNeeded(currentTitle)
        .onChange(of: availableSections) {
            validateSelection()
        }
        .onChange(of: feedManager.lists) {
            validateSelection()
        }
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
