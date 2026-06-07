import SwiftUI
import Hanami

struct HomeSectionBarHostView: View {

    let selectionStore: HomeSelectionStore
    let tabs: [HomeSectionBarItem]

    var body: some View {
        HomeSectionBar(tabs: tabs, selectionStore: selectionStore)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}
