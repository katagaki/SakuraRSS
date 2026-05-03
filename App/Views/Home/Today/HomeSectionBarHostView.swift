import SwiftUI

struct HomeSectionBarHostView: View {

    @Binding var selection: HomeSelection
    let tabs: [HomeSectionBarItem]
    @Binding var tabFrames: [String: CGRect]

    var body: some View {
        HomeSectionBar(tabs: tabs, selection: $selection, tabFrames: $tabFrames)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}
