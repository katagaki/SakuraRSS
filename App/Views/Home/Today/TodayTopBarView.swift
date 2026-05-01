import SwiftUI

struct TodayTopBarView: View {

    @Binding var selection: HomeSelection
    let tabs: [TodayTabItem]
    @Binding var tabFrames: [String: CGRect]

    var body: some View {
        TodayTabBar(tabs: tabs, selection: $selection, tabFrames: $tabFrames)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}
