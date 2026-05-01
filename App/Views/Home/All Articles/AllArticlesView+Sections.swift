import SwiftUI

extension AllArticlesView {

    var availableSections: [HomeSection] {
        HomeSection.allCases.filter { section in
            guard let feedSection = section.feedSection else { return true }
            return feedManager.hasFeeds(for: feedSection)
        }
    }

    func validateSelection() {
        switch selectedSelection {
        case .section(let section):
            if !availableSections.contains(section) {
                selectedSelection = .section(.all)
            }
        case .list(let id):
            if !feedManager.lists.contains(where: { $0.id == id }) {
                selectedSelection = .section(.all)
            }
        case .topic:
            // Validated against the dynamic top-N list at the HomeView level.
            break
        }
    }
}
