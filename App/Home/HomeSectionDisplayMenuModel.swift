import SwiftUI
import Hanami

@MainActor
@Observable
final class HomeSectionDisplayMenuModel {
    var isActive: Bool = false
    var styleBinding: Binding<FeedDisplayStyle>?
    var hasImages: Bool = false
    var showTimeline: Bool = false
    var showPodcast: Bool = false
}

private struct HomeSectionDisplayMenuKey: EnvironmentKey {
    static let defaultValue: HomeSectionDisplayMenuModel? = nil
}

extension EnvironmentValues {
    var homeSectionDisplayMenu: HomeSectionDisplayMenuModel? {
        get { self[HomeSectionDisplayMenuKey.self] }
        set { self[HomeSectionDisplayMenuKey.self] = newValue }
    }
}
