import SwiftUI
import Hanami

struct BrowserFavouriteCell: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    let feed: Feed

    private var unreadCount: Int {
        feedManager.unreadCount(for: feed)
    }

    var body: some View {
        Button {
            store.navigate(to: .feed(feed.id))
        } label: {
            VStack(spacing: 8) {
                FeedIcon(feed: feed, size: 56, cornerRadius: 14)
                    .overlay(alignment: .topTrailing) {
                        if unreadCount > 0 {
                            unreadBadge
                                .offset(x: 6, y: -6)
                        }
                    }
                Text(feed.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.openTab(at: .feed(feed.id), inBackground: true)
            } label: {
                Label(String(localized: "Menu.OpenInNewTab", table: "Browser"),
                      systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                favourites.toggle(feed.id)
            } label: {
                Label(String(localized: "Menu.RemoveFromFavourites", table: "Browser"),
                      systemImage: "star.slash")
            }
        }
    }

    private var unreadBadge: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.accentColor, in: .capsule)
    }
}
