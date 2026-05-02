import SwiftUI

struct FollowingFeedContextMenu: View {

    @Environment(FeedManager.self) private var feedManager
    let feed: Feed
    @Binding var feedForEditSheet: FeedIDIdentifier?
    @Binding var feedToDelete: Feed?

    var body: some View {
        let target = feed
        Button {
            feedManager.toggleMuted(target)
        } label: {
            Label(
                target.isMuted
                    ? String(localized: "FeedMenu.Unmute", table: "Feeds")
                    : String(localized: "FeedMenu.Mute", table: "Feeds"),
                systemImage: target.isMuted ? "bell" : "bell.slash"
            )
        }
        Button {
            feedForEditSheet = FeedIDIdentifier(id: target.id)
        } label: {
            Label(String(localized: "FeedMenu.Edit", table: "Feeds"),
                  systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            feedToDelete = target
        } label: {
            Label(String(localized: "FeedMenu.Delete", table: "Feeds"),
                  systemImage: "trash")
        }
    }
}
