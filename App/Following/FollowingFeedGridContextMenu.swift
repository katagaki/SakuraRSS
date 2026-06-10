import SwiftUI
import Hanami

struct FollowingFeedGridContextMenu: View {

    @Environment(FeedManager.self) private var feedManager
    let feed: Feed
    @Binding var feedToEdit: Feed?
    @Binding var feedForRules: Feed?
    @Binding var feedToDelete: Feed?

    var body: some View {
        Button {
            feedToEdit = feed
        } label: {
            Label(String(localized: "FeedMenu.Edit", table: "Feeds"),
                  systemImage: "pencil")
        }
        Button {
            feedForRules = feed
        } label: {
            Label(String(localized: "FeedMenu.Rules", table: "Feeds"),
                  systemImage: "list.bullet.rectangle")
        }
        Divider()
        let availableLists = listsNotContainingFeed
        if !availableLists.isEmpty {
            Menu {
                ForEach(availableLists) { list in
                    Button {
                        feedManager.addFeedToList(list, feed: feed)
                    } label: {
                        Label(list.name, systemImage: list.icon)
                    }
                }
            } label: {
                Label(String(localized: "FeedMenu.AddToList", table: "Feeds"),
                      systemImage: "text.badge.plus")
            }
            Divider()
        }
        Button(role: .destructive) {
            feedToDelete = feed
        } label: {
            Label(String(localized: "FeedMenu.Unfollow", table: "Feeds"),
                  image: "dot.radiowaves.up.forward.slash")
        }
    }

    private var listsNotContainingFeed: [FeedList] {
        let assignedListIDs = feedManager.listIDsForFeed(feed)
        return feedManager.lists
            .filter { !assignedListIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
