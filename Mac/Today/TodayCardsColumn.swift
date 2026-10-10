import Hanami
import SwiftUI

struct TodayCardsColumn: View {

    let model: TodayModel
    let feedManager: FeedManager
    let actions: TodayActions
    let revisions: WindowDataRevisions

    var body: some View {
        ScrollView {
            TodayCardSections(model: model, feedManager: feedManager, actions: actions)
                .padding(.vertical, 24)
        }
        .task(id: revisions.dataRevision + revisions.recentsRevision) {
            await model.load(feeds: feedManager.feeds)
        }
    }
}
