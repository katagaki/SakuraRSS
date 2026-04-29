import SwiftUI

extension AllArticlesView {

    static let videoSectionSet: Set<HomeSection> = [.youtube, .vimeo, .niconico]

    var availableSections: [HomeSection] {
        HomeSection.allCases.filter { section in
            guard let feedSection = section.feedSection else { return true }
            return feedManager.hasFeeds(for: feedSection)
        }
    }

    var followingSections: [HomeSection] {
        availableSections.filter { $0 == .all }
    }

    var primarySections: [HomeSection] {
        availableSections.filter { $0 == .feeds || $0 == .podcasts }
    }

    var socialSections: [HomeSection] {
        availableSections.filter {
            $0 != .all && $0 != .feeds && $0 != .podcasts
                && !Self.videoSectionSet.contains($0)
        }
    }

    var videoSections: [HomeSection] {
        availableSections.filter { Self.videoSectionSet.contains($0) }
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
        }
    }

    @ViewBuilder
    func sectionButton(for section: HomeSection) -> some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                selectedSelection = .section(section)
            }
        } label: {
            if let systemImage = section.systemImage {
                Label(section.localizedTitle, systemImage: systemImage)
            } else {
                Text(section.localizedTitle)
            }
        }
    }
}
