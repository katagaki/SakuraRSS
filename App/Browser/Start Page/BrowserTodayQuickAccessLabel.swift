import SwiftUI
import Hanami

struct BrowserTodayQuickAccessLabel: View {

    @Environment(FeedManager.self) private var feedManager
    let item: TodayQuickAccessItem
    var isEditing: Bool = false

    var body: some View {
        switch item {
        case .list(let listID):
            if let list = feedManager.lists.first(where: { $0.id == listID }) {
                FollowingListGridCell(list: list, isWiggling: isEditing)
            }
        case .feedSection(let section):
            BrowserTodayQuickAccessCell(
                title: item.browserTitle(in: feedManager),
                symbolName: item.browserSymbolName(in: feedManager),
                section: section
            )
        default:
            BrowserTodayQuickAccessCell(
                title: item.browserTitle(in: feedManager),
                symbolName: item.browserSymbolName(in: feedManager)
            )
        }
    }
}
