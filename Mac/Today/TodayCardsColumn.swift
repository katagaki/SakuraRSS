import Hanami
import SwiftUI

struct TodayCardsColumn: View {

    let model: TodayModel
    let feedManager: FeedManager
    let actions: TodayActions

    var body: some View {
        ScrollView {
            TodayCardSections(model: model, feedManager: feedManager, actions: actions)
                .padding(.vertical, 24)
        }
        .task(id: feedManager.dataRevision) {
            await model.load(feeds: feedManager.feeds)
        }
    }
}
