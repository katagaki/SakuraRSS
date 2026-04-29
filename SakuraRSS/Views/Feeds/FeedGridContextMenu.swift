import SwiftUI

struct FeedGridContextMenu: View {

    @Environment(FeedManager.self) private var feedManager
    let feed: Feed
    @Binding var feedToEdit: Feed?
    @Binding var feedForRules: Feed?
    @Binding var feedToDelete: Feed?
    @Binding var feedForListAssignment: Feed?

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
            feedForRules = target
        } label: {
            Label(String(localized: "FeedMenu.Rules", table: "Feeds"),
                  systemImage: "list.bullet.rectangle")
        }
        Button {
            feedForListAssignment = target
        } label: {
            Label(String(localized: "FeedMenu.AddToList", table: "Feeds"),
                  systemImage: "text.badge.plus")
        }
        Divider()
        Button {
            feedToEdit = target
        } label: {
            Label(String(localized: "FeedMenu.Edit", table: "Feeds"),
                  systemImage: "pencil")
        }
        Button(role: .destructive) {
            feedToDelete = target
        } label: {
            Label(String(localized: "FeedMenu.Delete", table: "Feeds"),
                  systemImage: "trash")
        }
    }
}
